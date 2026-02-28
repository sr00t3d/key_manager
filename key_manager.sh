#!/bin/bash

# ==============================================================================
# Key Manager 🔑 - v3.0 (Clean Architecture & Audit)
# ==============================================================================

# --- Cores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Variáveis Globais ---
PORT="22"
KEYNAME="id_rsa"
REMOTE_USER="root"
FORCE_UPDATE=false
SERVER_IP=""
PASSWORD=""

# --- Origem & Auditoria ---
MY_HOSTNAME=$(hostname)
MY_IP=$(curl -s --connect-timeout 2 ifconfig.me || hostname -I | awk '{print $1}')
TIMESTAMP=$(date +'%d/%m/%Y %H:%M:%S')
COMMENT="${MY_HOSTNAME} (${MY_IP}) - ${TIMESTAMP}"

# --- Limpeza Automática (Trap) ---
# Se o script for interrompido (Ctrl+C) ou terminar, apaga arquivos temporários
trap 'rm -f /tmp/deploy_*.pub; unset PASSWORD' EXIT INT TERM

# --- Funções Auxiliares ---

# Função para conectar ao servidor (Evita repetir o comando SSH)
connect_to_server() {
    ssh -i "$KEY_PATH" -p "$PORT" "$REMOTE_USER@$SERVER_IP"
}

# Função de Auditoria
remote_audit() {
    local action=$1
    local audit_cmd="echo \"[${TIMESTAMP}] ACTION: ${action} | FROM: ${MY_IP} | HOST: ${MY_HOSTNAME}\" | sudo tee -a /var/log/key.audit > /dev/null"
    
    if [ -n "$PASSWORD" ]; then
        sshpass -p "$PASSWORD" ssh -p "$PORT" -o StrictHostKeyChecking=no -o PubkeyAuthentication=no "$REMOTE_USER@$SERVER_IP" "$audit_cmd" 2>/dev/null
    else
        ssh -p "$PORT" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$REMOTE_USER@$SERVER_IP" "$audit_cmd" 2>/dev/null
    fi
}

# --- Parsing de Argumentos ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -u) REMOTE_USER="$2"; shift 2 ;;
    -p) 
      [[ -z "$2" || "$2" == -* ]] && { echo -e "${RED}❌ Erro: -p requer senha.${NC}"; exit 1; }
      PASSWORD="$2"; shift 2 ;;
    -P) 
      [[ -z "$2" || "$2" == -* ]] && { echo -e "${RED}❌ Erro: -P requer a porta.${NC}"; exit 1; }
      PORT="$2"; shift 2 ;;
    -n) KEYNAME="$2"; shift 2 ;;
    -c) COMMENT="$2"; shift 2 ;;
    -k) FORCE_UPDATE=true; shift 1 ;;
    -h) echo "Ajuda..."; exit 0 ;;
    *) 
      [[ ! "$1" =~ ^- ]] && [[ -z "$SERVER_IP" ]] && SERVER_IP="$1"
      shift 1 ;;
  esac
done

[[ -z "$SERVER_IP" ]] && { echo -e "${RED}❌ Erro: IP do servidor não especificado.${NC}"; exit 1; }

# Caminhos
KEY_PATH="$HOME/.ssh/$KEYNAME"
PUB_KEY="${KEY_PATH}.pub"

# --- Execução Principal ---

# 1. Garantir chave local
[ ! -f "$KEY_PATH" ] && ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -C "$COMMENT" -N "" > /dev/null

# 2. Update Forçado (-k)
if [ "$FORCE_UPDATE" = true ] && [ -n "$PASSWORD" ]; then
    echo -e "${YELLOW}🔄 Removendo registros antigos...${NC}"
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[$SERVER_IP]:$PORT" &>/dev/null
    sshpass -p "$PASSWORD" ssh -p "$PORT" -o StrictHostKeyChecking=no -o PubkeyAuthentication=no "$REMOTE_USER@$SERVER_IP" "rm -f ~/.ssh/authorized_keys" 2>/dev/null
fi

# 3. Teste de Conexão
echo -e "${BLUE}🔍 Verificando acesso a $REMOTE_USER@$SERVER_IP:$PORT...${NC}"

if ssh -i "$KEY_PATH" -p "$PORT" -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$REMOTE_USER@$SERVER_IP" true 2>/dev/null; then
    echo -e "${GREEN}✨ Acesso via chave OK!${NC}"
    remote_audit "LOGIN_SUCCESS"
    connect_to_server
    exit 0
fi

# 4. Deploy Automático
echo -e "${YELLOW}⚠️  Acesso negado. Iniciando deploy...${NC}"

if [ -n "$PASSWORD" ]; then
    ssh-keyscan -p "$PORT" "$SERVER_IP" >> "$HOME/.ssh/known_hosts" 2>/dev/null
    
    TEMP_PUB="/tmp/deploy_$(date +%s).pub"
    awk '{print $1, $2, "'"$COMMENT"'"}' "$PUB_KEY" > "$TEMP_PUB"

    # Redirecionamos a saída normal para /dev/null para um visual mais limpo
    if sshpass -p "$PASSWORD" ssh-copy-id -f -i "$TEMP_PUB" -p "$PORT" -o PubkeyAuthentication=no -o StrictHostKeyChecking=no "$REMOTE_USER@$SERVER_IP" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Deploy concluído com sucesso!${NC}"
        remote_audit "KEY_DEPLOYED"
        connect_to_server
    else
        echo -e "${RED}❌ Falha no deploy. O servidor pode ter bloqueado logins por senha.${NC}"
    fi
else
    echo -e "${RED}❌ Erro: Senha (-p) é obrigatória para o primeiro deploy.${NC}"
fi
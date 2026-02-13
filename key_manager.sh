#!/bin/bash
################################################################################
#                                                                              #
#   PROJECT: Server Key Manager                                                #
#   VERSION: 1.1.0                                                             #
#                                                                              #
#   AUTHOR:  Percio Andrade                                                    #
#   CONTACT: percio@evolya.com.br | contato@perciocastelo.com.br               #
#   WEB:     https://perciocastelo.com.br                                      #
#                                                                              #
#   INFO:                                                                      #
#   Manage SSH keys, handle IPv4/IPv6 and automate connections.                #
#                                                                              #
################################################################################

# --- CONFIGURATION ---
SSH_USER="root"
SSH_PORT="22"
KEY_NAME="id_rsa"
UPDATE_KEY=false
COPY_KEY=false
QUIET_MODE=false
ROOT_PASS=""
# ---------------------

# Detect System Language
SYSTEM_LANG="${LANG:0:2}"

if [[ "$SYSTEM_LANG" == "pt" ]]; then
    # Portuguese Strings
    MSG_USAGE="Uso: $0 server_ip [-u] [-p password] [-P port] [-c] [-n keyname] [-q]"
    MSG_ERR_IP="ERRO: O primeiro argumento deve ser um IP válido."
    MSG_ERR_CMD="ERRO: Comando necessário não encontrado:"
    MSG_ERR_INSTALL="Por favor, instale os pacotes necessários manualmente."
    MSG_KEY_GEN="Gerando/Atualizando chave SSH"
    MSG_KEY_COPY="Copiando chave pública para o servidor"
    MSG_KEY_EXISTS="Chave SSH já existe. Use -u para atualizar."
    MSG_CONNECT="Conectando ao servidor"
    MSG_SUCCESS="Sucesso"
else
    # English Strings (Default)
    MSG_USAGE="Usage: $0 server_ip [-u] [-p password] [-P port] [-c] [-n keyname] [-q]"
    MSG_ERR_IP="ERROR: The first argument must be a valid IP address."
    MSG_ERR_CMD="ERROR: Required command not found:"
    MSG_ERR_INSTALL="Please install missing packages manually."
    MSG_KEY_GEN="Generating/Updating SSH key"
    MSG_KEY_COPY="Copying public key to server"
    MSG_KEY_EXISTS="SSH key already exists. Use -u to update."
    MSG_CONNECT="Connecting to server"
    MSG_SUCCESS="Success"
fi

# Logging function
log() {
    if [ "$QUIET_MODE" = false ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] - $1"
    fi
}

# Validate IP (IPv4 or IPv6)
validate_ip() {
    local ip=$1
    # IPv4 Regex
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    # IPv6 Regex
    elif [[ $ip =~ ^([0-9a-fA-F:]+:+)+[0-9a-fA-F]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check for IPv6 to add brackets
is_ipv6() {
    local ip=$1
    if [[ $ip =~ ^([0-9a-fA-F:]+:+)+[0-9a-fA-F]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check dependencies
check_dependencies() {
    local missing=0
    for cmd in ssh-keygen ssh-copy-id ssh ssh-keyscan; do
        if ! command -v $cmd &> /dev/null; then
            log "$MSG_ERR_CMD $cmd"
            missing=1
        fi
    done

    # sshpass is only needed if password is provided
    if [ ! -z "$ROOT_PASS" ]; then
        if ! command -v sshpass &> /dev/null; then
             log "$MSG_ERR_CMD sshpass"
             missing=1
        fi
    fi

    if [ $missing -eq 1 ]; then
        log "$MSG_ERR_INSTALL"
        exit 1
    fi
}

# --- ARGUMENT PARSING ---

# Help
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "$MSG_USAGE"
    exit 0
fi

# IP Check
SERVER_IP="$1"
if ! validate_ip "$SERVER_IP"; then
    log "$MSG_ERR_IP"
    echo "$MSG_USAGE"
    exit 1
fi
shift # Remove IP from args

# Parse Options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -u) UPDATE_KEY=true ;;
        -p) ROOT_PASS="$2"; shift ;;
        -P) SSH_PORT="$2"; shift ;;
        -c) COPY_KEY=true ;;
        -n) KEY_NAME="$2"; shift ;;
        -q) QUIET_MODE=true ;;
        *)  log "Invalid option: $1"; exit 1 ;;
    esac
    shift
done

# --- MAIN LOGIC ---

check_dependencies

KEY_PATH="$HOME/.ssh/$KEY_NAME"
PUB_KEY_PATH="$KEY_PATH.pub"

# 1. Generate Key if missing or requested update
if [ ! -f "$KEY_PATH" ] || [ "$UPDATE_KEY" = true ]; then
    log "$MSG_KEY_GEN: $KEY_NAME"
    # -f forces filename, -N "" creates no passphrase
    yes y | ssh-keygen -t rsa -b 4096 -C "$SSH_USER@$(hostname)" -N "" -f "$KEY_PATH" >/dev/null 2>&1
    COPY_KEY=true # If new key, force copy
else
    log "$MSG_KEY_EXISTS"
fi

# 2. Copy Key to Server (if requested or new)
if [ "$COPY_KEY" = true ]; then
    log "$MSG_KEY_COPY ($SERVER_IP:$SSH_PORT)..."
    
    # Add to known_hosts to avoid "yes/no" prompt blocking automation
    ssh-keyscan -p "$SSH_PORT" "$SERVER_IP" >> "$HOME/.ssh/known_hosts" 2>/dev/null

    if [ -n "$ROOT_PASS" ]; then
        # Use sshpass if password provided
        # -i specifies WHICH key to copy (Critical fix)
        sshpass -p "$ROOT_PASS" ssh-copy-id -i "$PUB_KEY_PATH" -p "$SSH_PORT" "$SSH_USER@$SERVER_IP" >/dev/null 2>&1
    else
        # Interactive mode
        ssh-copy-id -i "$PUB_KEY_PATH" -p "$SSH_PORT" "$SSH_USER@$SERVER_IP"
    fi
fi

# 3. Connect via SSH
log "$MSG_CONNECT..."

if is_ipv6 "$SERVER_IP"; then
    TARGET="[$SERVER_IP]"
else
    TARGET="$SERVER_IP"
fi

# Use -i to ensure we use the specific key we just managed
ssh -i "$KEY_PATH" -p "$SSH_PORT" "$SSH_USER@$TARGET"

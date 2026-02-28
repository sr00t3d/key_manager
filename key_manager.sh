#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   Key Manager v3.0.0                                                      ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Author:   Percio Castelo                                                ║
# ║   Contact:  percio@evolya.com.br | contato@perciocastelo.com.br           ║
# ║   Web:      https://perciocastelo.com.br                                  ║
# ║                                                                           ║
# ║   Function: Manage SSH Keys                                               ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Global Variables ---
PORT="22"
KEYNAME="id_rsa"
REMOTE_USER="root"
FORCE_UPDATE=false
SERVER_IP=""
PASSWORD=""

# --- Origin and Audit ---
MY_HOSTNAME=$(hostname)
MY_IP=$(curl -s --connect-timeout 2 ifconfig.me || hostname -I | awk '{print $1}')
TIMESTAMP=$(date +'%d/%m/%Y %H:%M:%S')
COMMENT="${MY_HOSTNAME} (${MY_IP}) - ${TIMESTAMP}"

# --- Automatic Cleanup (Trap) ---
# If the script is interrupted (Ctrl+C) or terminates, it deletes temporary files
trap 'rm -f /tmp/deploy_*.pub; unset PASSWORD' EXIT INT TERM

# --- Auxiliary Functions ---

# Function to connect to the server (Avoids repeating the SSH command)
connect_to_server() {
    ssh -i "$KEY_PATH" -p "$PORT" "$REMOTE_USER@$SERVER_IP"
}

# Audit Function
remote_audit() {
    local action=$1
    local audit_cmd="echo \"[${TIMESTAMP}] ACTION: ${action} | FROM: ${MY_IP} | HOST: ${MY_HOSTNAME}\" | sudo tee -a /var/log/key.audit > /dev/null"
    
    if [ -n "$PASSWORD" ]; then
        sshpass -p "$PASSWORD" ssh -p "$PORT" -o StrictHostKeyChecking=no -o PubkeyAuthentication=no "$REMOTE_USER@$SERVER_IP" "$audit_cmd" 2>/dev/null
    else
        ssh -p "$PORT" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$REMOTE_USER@$SERVER_IP" "$audit_cmd" 2>/dev/null
    fi
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -u) REMOTE_USER="$2"; shift 2 ;;
    -p) 
      [[ -z "$2" || "$2" == -* ]] && { echo -e "${RED}❌ Error: -p requires a password.${NC}"; exit 1; }
      PASSWORD="$2"; shift 2 ;;
    -P) 
      [[ -z "$2" || "$2" == -* ]] && { echo -e "${RED}❌ Error: -P requires a port.${NC}"; exit 1; }
      PORT="$2"; shift 2 ;;
    -n) KEYNAME="$2"; shift 2 ;;
    -c) COMMENT="$2"; shift 2 ;;
    -k) FORCE_UPDATE=true; shift 1 ;;
    -h) echo "Help..."; exit 0 ;;
    *) 
      [[ ! "$1" =~ ^- ]] && [[ -z "$SERVER_IP" ]] && SERVER_IP="$1"
      shift 1 ;;
  esac
done

[[ -z "$SERVER_IP" ]] && { echo -e "${RED}❌ Error: Server IP not specified.${NC}"; exit 1; }

# Paths
KEY_PATH="$HOME/.ssh/$KEYNAME"
PUB_KEY="${KEY_PATH}.pub"

# --- Main Execution ---

# 1. Secure local key
[ ! -f "$KEY_PATH" ] && ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -C "$COMMENT" -N "" > /dev/null

# 2. Forced Update (-k)
if [ "$FORCE_UPDATE" = true ] && [ -n "$PASSWORD" ]; then
    echo -e "${YELLOW}🔄 Removing old records...${NC}"
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[$SERVER_IP]:$PORT" &>/dev/null
    sshpass -p "$PASSWORD" ssh -p "$PORT" -o StrictHostKeyChecking=no -o PubkeyAuthentication=no "$REMOTE_USER@$SERVER_IP" "rm -f ~/.ssh/authorized_keys" 2>/dev/null
fi

# 3. Connection Test
echo -e "${BLUE}🔍 Checking access to $REMOTE_USER@$SERVER_IP:$PORT...${NC}"

if ssh -i "$KEY_PATH" -p "$PORT" -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$REMOTE_USER@$SERVER_IP" true 2>/dev/null; then
    echo -e "${GREEN}✨ Key access OK!${NC}"
    remote_audit "LOGIN_SUCCESS"
    connect_to_server
    exit 0
fi

# 4. Automatic Deploy
echo -e "${YELLOW}⚠️  Access denied. Starting deploy...${NC}"

if [ -n "$PASSWORD" ]; then
    ssh-keyscan -p "$PORT" "$SERVER_IP" >> "$HOME/.ssh/known_hosts" 2>/dev/null
    
    TEMP_PUB="/tmp/deploy_$(date +%s).pub"
    awk '{print $1, $2, "'"$COMMENT"'"}' "$PUB_KEY" > "$TEMP_PUB"

    # Normal output redirected to /dev/null for a cleaner display
    if sshpass -p "$PASSWORD" ssh-copy-id -f -i "$TEMP_PUB" -p "$PORT" -o PubkeyAuthentication=no -o StrictHostKeyChecking=no "$REMOTE_USER@$SERVER_IP" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Deploy completed successfully!${NC}"
        remote_audit "KEY_DEPLOYED"
        connect_to_server
    else
        echo -e "${RED}❌ Deploy failed. The server may have blocked password logins.${NC}"
    fi
else
    echo -e "${RED}❌ Error: Password (-p) is required for the first deploy.${NC}"
fi
#!/usr/bin/env bash
# +============================================================================+
# | key_manager.sh                                                             |
# | SSH Key Manager v3.1.0                                                     |
# | Automates SSH keypair generation (Ed25519 / RSA 4096), permission          |
# | enforcement, SHA256 fingerprint inspection, remote deployment, audit       |
# | logging, dry-run simulation, and table/JSON/CSV reporting.                 |
# |                                                                            |
# | Author:  Percio Castelo                                                    |
# | Contact: percio@evolya.com.br | contato@perciocastelo.com.br               |
# | Web:     https://perciocastelo.com.br                                      |
# | Repo:    https://github.com/sr00t3d/key_manager                            |
# |                                                                            |
# | Copyright 2024-2026 Percio Castelo                                         |
# | SPDX-License-Identifier: Apache-2.0                                        |
# +============================================================================+

set -uo pipefail

readonly VERSION="3.1.0"
readonly SCRIPT_NAME="$(basename "$0")"

# ---- Defaults ---------------------------------------------------------------
SERVER_HOST=""
REMOTE_USER="root"
PORT="22"
KEY_TYPE="ed25519"
KEY_DIR="${HOME}/.ssh"
KEY_NAME=""
COMMENT=""
PASSWORD="${SSHPASS:-}"
REFRESH_KNOWN_HOSTS=0
CHECK_ONLY=0
NO_CONNECT=0
NO_AUDIT=0
DRY_RUN=0
OUTPUT_FORMAT="table"
QUIET=0
NO_COLOR=0

TEMP_PUB=""
cleanup() {
    if [[ -n "${TEMP_PUB:-}" && -f "$TEMP_PUB" ]]; then
        rm -f "$TEMP_PUB"
    fi
    unset PASSWORD SSHPASS 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ---- Color helpers ----------------------------------------------------------
init_colors() {
    if [[ "$NO_COLOR" -eq 1 || ! -t 1 ]]; then
        C_RESET="" C_BOLD="" C_GREEN="" C_YELLOW="" C_RED="" C_CYAN=""
    else
        C_RESET=$'\033[0m'
        C_BOLD=$'\033[1m'
        C_GREEN=$'\033[32m'
        C_YELLOW=$'\033[33m'
        C_RED=$'\033[31m'
        C_CYAN=$'\033[36m'
    fi
}

# ---- Help & Version ---------------------------------------------------------
show_version() {
    echo "SSH Key Manager v${VERSION}"
}

show_help() {
    cat <<EOF
SSH Key Manager v${VERSION}
Automates SSH key generation, verification, deployment, and audit logging.

Usage: ${SCRIPT_NAME} <HOST> [OPTIONS]

Options:
  -u, --user USER         Remote SSH username (default: root)
  -P, --port PORT         Remote SSH port (default: 22)
  -t, --type TYPE         Key algorithm: ed25519 (default) or rsa (4096-bit)
  -n, --key-name NAME     Key filename inside --key-dir (default: id_<type>)
  --key-dir DIR           Directory storing SSH keys (default: ~/.ssh)
  -c, --comment TEXT      Custom SSH key comment
  -p, --password PASS     Remote password for initial deploy (prefer SSHPASS env var)
  -k, --refresh           Refresh host entry in known_hosts before connecting
  --check-only            Validate local key & remote pubkey auth without deploying or connecting
  --no-connect            Exit cleanly after verification/deploy without opening interactive shell
  --no-audit              Skip writing audit record to remote /var/log/key.audit
  --dry-run               Preview actions without creating keys or modifying remote host
  -o, --output FORMAT     Output format: table (default), json, csv
  -q, --quiet             Suppress standard output (errors still go to stderr)
  --no-color              Disable ANSI colors
  -V, --version           Show version and exit
  -h, --help              Show this help and exit

Examples:
  ${SCRIPT_NAME} 192.0.2.10 --check-only -u root -P 2222
  ${SCRIPT_NAME} server.example.com --dry-run -t ed25519 -o json
  SSHPASS='secret' ${SCRIPT_NAME} 192.0.2.10 -u admin --no-connect -o csv
  ${SCRIPT_NAME} server.example.com -u root -P 2222 -n id_prod
EOF
}

# ---- Argument Parser --------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires a username." >&2; exit 1; }
            REMOTE_USER="$2"; shift 2 ;;
        -P|--port)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires a port number." >&2; exit 1; }
            PORT="$2"; shift 2 ;;
        -t|--type)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires 'ed25519' or 'rsa'." >&2; exit 1; }
            KEY_TYPE="$2"; shift 2 ;;
        -n|--key-name)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires a key filename." >&2; exit 1; }
            KEY_NAME="$2"; shift 2 ;;
        --key-dir)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires a directory path." >&2; exit 1; }
            KEY_DIR="$2"; shift 2 ;;
        -c|--comment)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires a comment string." >&2; exit 1; }
            COMMENT="$2"; shift 2 ;;
        -p|--password)
            [[ $# -lt 2 || "$2" == -* ]] && { echo "ERROR: $1 requires a password." >&2; exit 1; }
            PASSWORD="$2"; shift 2 ;;
        -k|--refresh)
            REFRESH_KNOWN_HOSTS=1; shift ;;
        --check-only)
            CHECK_ONLY=1; NO_CONNECT=1; shift ;;
        --no-connect)
            NO_CONNECT=1; shift ;;
        --no-audit)
            NO_AUDIT=1; shift ;;
        --dry-run)
            DRY_RUN=1; NO_CONNECT=1; shift ;;
        -o|--output)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires table, json, or csv." >&2; exit 1; }
            OUTPUT_FORMAT="$2"; shift 2 ;;
        -q|--quiet)
            QUIET=1; shift ;;
        --no-color)
            NO_COLOR=1; shift ;;
        -V|--version)
            show_version; exit 0 ;;
        -h|--help)
            show_help; exit 0 ;;
        -*)
            echo "ERROR: Unknown option: $1 (run with -h for usage)" >&2
            exit 1 ;;
        *)
            if [[ -z "$SERVER_HOST" ]]; then
                SERVER_HOST="$1"
            else
                echo "ERROR: Unexpected positional argument: $1" >&2
                exit 1
            fi
            shift ;;
    esac
done

init_colors

# ---- Validations ------------------------------------------------------------
if [[ -z "$SERVER_HOST" ]]; then
    echo "${C_RED}ERROR: Target host/IP is required (run with -h for usage).${C_RESET}" >&2
    exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 || "$PORT" -gt 65535 ]]; then
    echo "${C_RED}ERROR: Invalid port '${PORT}'. Must be 1-65535.${C_RESET}" >&2
    exit 1
fi

case "$KEY_TYPE" in
    ed25519) [[ -z "$KEY_NAME" ]] && KEY_NAME="id_ed25519" ;;
    rsa)     [[ -z "$KEY_NAME" ]] && KEY_NAME="id_rsa" ;;
    *)
        echo "${C_RED}ERROR: Invalid key type '${KEY_TYPE}'. Expected 'ed25519' or 'rsa'.${C_RESET}" >&2
        exit 1 ;;
esac

case "$OUTPUT_FORMAT" in
    table|json|csv) ;;
    *)
        echo "${C_RED}ERROR: Invalid output format '${OUTPUT_FORMAT}'. Expected table, json, or csv.${C_RESET}" >&2
        exit 1 ;;
esac

for bin in ssh ssh-keygen; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "${C_RED}ERROR: Required OpenSSH binary not found: ${bin}${C_RESET}" >&2
        exit 1
    fi
done

# ---- Derived Metadata -------------------------------------------------------
MY_HOSTNAME="$(hostname 2>/dev/null || echo unknown)"
TIMESTAMP_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
[[ -z "$COMMENT" ]] && COMMENT="${USER:-root}@${MY_HOSTNAME} (${TIMESTAMP_ISO})"

KEY_PATH="${KEY_DIR}/${KEY_NAME}"
PUB_KEY="${KEY_PATH}.pub"

KEY_STATE="EXISTS"
FINGERPRINT="-"
AUTH_STATUS="UNKNOWN"
AUDIT_STATUS="SKIPPED"
ACTION_TAKEN="NONE"
OVERALL_STATUS="SUCCESS"
EXIT_CODE=0

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

get_fingerprint() {
    local pub="$1"
    if [[ -f "$pub" ]]; then
        ssh-keygen -lf "$pub" 2>/dev/null | awk '{print $2}' || echo "-"
    else
        echo "-"
    fi
}

detect_key_type() {
    local pub="$1"
    if [[ -f "$pub" ]]; then
        local raw
        raw="$(ssh-keygen -lf "$pub" 2>/dev/null | awk '{print tolower($NF)}' | tr -d '()')"
        [[ -n "$raw" ]] && echo "$raw" || echo "$KEY_TYPE"
    else
        echo "$KEY_TYPE"
    fi
}

remote_audit() {
    local action="$1"
    if [[ "$NO_AUDIT" -eq 1 || "$DRY_RUN" -eq 1 ]]; then
        AUDIT_STATUS="SKIPPED"
        return 0
    fi
    local audit_line="[${TIMESTAMP_ISO}] ACTION=${action} HOST=${MY_HOSTNAME} USER=${REMOTE_USER} KEY=${KEY_NAME}"
    local audit_cmd="printf '%s\n' '${audit_line}' >> /var/log/key.audit 2>/dev/null || true"
    if ssh -i "$KEY_PATH" -p "$PORT" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${REMOTE_USER}@${SERVER_HOST}" "$audit_cmd" 2>/dev/null; then
        AUDIT_STATUS="RECORDED"
    else
        AUDIT_STATUS="FAILED"
    fi
}

# ---- Step 1: Local Key Management ------------------------------------------
if [[ -f "$KEY_PATH" && -f "$PUB_KEY" ]]; then
    KEY_STATE="EXISTS"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        chmod 700 "$KEY_DIR" 2>/dev/null || true
        chmod 600 "$KEY_PATH" 2>/dev/null || true
        chmod 644 "$PUB_KEY" 2>/dev/null || true
    fi
    KEY_TYPE="$(detect_key_type "$PUB_KEY")"
    FINGERPRINT="$(get_fingerprint "$PUB_KEY")"
else
    if [[ "$DRY_RUN" -eq 1 ]]; then
        KEY_STATE="WOULD_GENERATE"
        FINGERPRINT="(pending generation)"
    elif [[ "$CHECK_ONLY" -eq 1 ]]; then
        KEY_STATE="MISSING"
        AUTH_STATUS="KEY_MISSING"
        OVERALL_STATUS="ERROR"
        EXIT_CODE=1
    else
        mkdir -p "$KEY_DIR"
        chmod 700 "$KEY_DIR"
        if [[ "$KEY_TYPE" == "ed25519" ]]; then
            ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$COMMENT" -N "" >/dev/null 2>&1
        else
            ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -C "$COMMENT" -N "" >/dev/null 2>&1
        fi
        chmod 600 "$KEY_PATH"
        chmod 644 "$PUB_KEY"
        KEY_STATE="GENERATED"
        FINGERPRINT="$(get_fingerprint "$PUB_KEY")"
    fi
fi

# ---- Step 2: Optional known_hosts refresh -----------------------------------
if [[ "$REFRESH_KNOWN_HOSTS" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "[${SERVER_HOST}]:${PORT}" >/dev/null 2>&1 || true
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${SERVER_HOST}" >/dev/null 2>&1 || true
fi

# ---- Step 3: Connectivity & Deploy Flow -------------------------------------
if [[ "$DRY_RUN" -eq 1 ]]; then
    AUTH_STATUS="WOULD_CHECK"
    ACTION_TAKEN="DRY_RUN"
    OVERALL_STATUS="DRY_RUN"
elif [[ "$EXIT_CODE" -eq 0 ]]; then
    if ssh -i "$KEY_PATH" -p "$PORT" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${REMOTE_USER}@${SERVER_HOST}" true 2>/dev/null; then
        AUTH_STATUS="AUTHORIZED"
        ACTION_TAKEN="VERIFIED"
        remote_audit "KEY_VERIFIED"
    elif [[ "$CHECK_ONLY" -eq 1 ]]; then
        AUTH_STATUS="UNAUTHORIZED"
        ACTION_TAKEN="CHECK_ONLY"
        OVERALL_STATUS="UNAUTHORIZED"
        EXIT_CODE=2
    else
        # Attempt deployment via ssh-copy-id + sshpass -e
        if [[ -z "$PASSWORD" ]]; then
            AUTH_STATUS="UNAUTHORIZED"
            ACTION_TAKEN="PASSWORD_REQUIRED"
            OVERALL_STATUS="ERROR"
            EXIT_CODE=2
        elif ! command -v sshpass >/dev/null 2>&1 || ! command -v ssh-copy-id >/dev/null 2>&1; then
            echo "${C_RED}ERROR: sshpass and ssh-copy-id are required for automated key deployment.${C_RESET}" >&2
            AUTH_STATUS="DEPLOY_TOOL_MISSING"
            ACTION_TAKEN="FAILED"
            OVERALL_STATUS="ERROR"
            EXIT_CODE=3
        else
            TEMP_PUB="$(mktemp /tmp/key_manager.XXXXXX.pub)"
            chmod 600 "$TEMP_PUB"
            awk -v c="$COMMENT" '{print $1, $2, c}' "$PUB_KEY" > "$TEMP_PUB"
            export SSHPASS="$PASSWORD"
            if sshpass -e ssh-copy-id -f -i "$TEMP_PUB" -p "$PORT" \
                -o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new \
                "${REMOTE_USER}@${SERVER_HOST}" >/dev/null 2>&1; then
                AUTH_STATUS="AUTHORIZED"
                ACTION_TAKEN="DEPLOYED"
                remote_audit "KEY_DEPLOYED"
            else
                AUTH_STATUS="DEPLOY_FAILED"
                ACTION_TAKEN="FAILED"
                OVERALL_STATUS="ERROR"
                EXIT_CODE=4
            fi
        fi
    fi
fi

# ---- Step 4: Output Report --------------------------------------------------
if [[ "$QUIET" -eq 0 ]]; then
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        printf '{\n'
        printf '  "version": "%s",\n' "$VERSION"
        printf '  "status": "%s",\n' "$OVERALL_STATUS"
        printf '  "target": "%s@%s:%s",\n' "$(json_escape "$REMOTE_USER")" "$(json_escape "$SERVER_HOST")" "$PORT"
        printf '  "key_path": "%s",\n' "$(json_escape "$KEY_PATH")"
        printf '  "key_type": "%s",\n' "$KEY_TYPE"
        printf '  "key_state": "%s",\n' "$KEY_STATE"
        printf '  "fingerprint": "%s",\n' "$(json_escape "$FINGERPRINT")"
        printf '  "auth_status": "%s",\n' "$AUTH_STATUS"
        printf '  "action": "%s",\n' "$ACTION_TAKEN"
        printf '  "audit": "%s",\n' "$AUDIT_STATUS"
        printf '  "dry_run": %s,\n' "$([[ "$DRY_RUN" -eq 1 ]] && echo true || echo false)"
        printf '  "timestamp": "%s"\n' "$TIMESTAMP_ISO"
        printf '}\n'
    elif [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "timestamp,target,key_path,key_type,key_state,fingerprint,auth_status,action,audit,status"
        printf '%s,"%s@%s:%s","%s",%s,%s,"%s",%s,%s,%s,%s\n' \
            "$TIMESTAMP_ISO" "$REMOTE_USER" "$SERVER_HOST" "$PORT" \
            "$KEY_PATH" "$KEY_TYPE" "$KEY_STATE" "$FINGERPRINT" \
            "$AUTH_STATUS" "$ACTION_TAKEN" "$AUDIT_STATUS" "$OVERALL_STATUS"
    else
        BORDER="+------------------+--------------------------------------------------------+"
        echo ""
        echo "${C_BOLD}SSH Key Manager v${VERSION}${C_RESET}"
        echo "$BORDER"
        printf "| %-16s | %-54s |\n" "Field" "Value"
        echo "$BORDER"
        printf "| %-16s | %-54s |\n" "Target" "${REMOTE_USER}@${SERVER_HOST}:${PORT}"
        printf "| %-16s | %-54s |\n" "Key Path" "${KEY_PATH}"
        printf "| %-16s | %-54s |\n" "Key Type" "${KEY_TYPE} (${KEY_STATE})"
        printf "| %-16s | %-54s |\n" "Fingerprint" "${FINGERPRINT}"
        printf "| %-16s | %-54s |\n" "Auth Status" "${AUTH_STATUS}"
        printf "| %-16s | %-54s |\n" "Action" "${ACTION_TAKEN}"
        printf "| %-16s | %-54s |\n" "Remote Audit" "${AUDIT_STATUS}"
        printf "| %-16s | %-54s |\n" "Overall Status" "${OVERALL_STATUS}"
        printf "| %-16s | %-54s |\n" "Timestamp" "${TIMESTAMP_ISO}"
        echo "$BORDER"
        echo ""
    fi
fi

# ---- Step 5: Optional Interactive Shell -------------------------------------
if [[ "$EXIT_CODE" -eq 0 && "$NO_CONNECT" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
    exec ssh -i "$KEY_PATH" -p "$PORT" "${REMOTE_USER}@${SERVER_HOST}"
fi

exit "$EXIT_CODE"

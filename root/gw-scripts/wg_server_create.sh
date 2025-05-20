#!/bin/bash

set -euo pipefail

# ─── Global Variables
ARG_DEVINT=
ARG_SERVERURL=
ARG_SERVERPORT=
ARG_PEERDNS=
ARG_INTERNAL_SUBNET=
ARG_ALLOWEDIPS=
ARG_PERSISTENT_KEEPALIVE=
ARG_USE_COREDNS=false
ARG_VERBOSE=false

# ─── Load Global Configuration
if [[ -f /gw-scripts/globals.env ]]; then
    source /gw-scripts/globals.env
else
    echo "**** [ERROR] globals.env not found at /gw-scripts/globals.env. Aborting. ****"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Functions
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

resolve_arg() {
    local arg_value="$1"
    local fallback_env="$2"
    local default="$3"
    [[ -n "$arg_value" ]] && echo "$arg_value" || echo "${!fallback_env:-$default}"
}

normalize_bool() {
    [[ "$1" == "true" ]] && echo "true" || echo "false"
}

is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]
}

debug() {
    if $ARG_VERBOSE; then
        echo "[DEBUG] $1"
    fi
}

list_servers() {
    SERVER_DIR_PREFIX="/config/server_"
    SERVERS=()
    for SERVER_DIR in ${SERVER_DIR_PREFIX}*; do
        if [[ -d "$SERVER_DIR" ]]; then
            SERVER_NAME=$(basename "$SERVER_DIR" | sed "s/server_//")
            SERVERS+=("\"$SERVER_NAME\"")
        fi
    done

    if [[ ${#SERVERS[@]} -eq 0 ]]; then
        echo "[]"
    else
        echo "[${SERVERS[*]}]" | sed 's/ /,/g'
    fi
    exit 0
}

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function usage {
    echo "Usage: $0 -D <DEVINT> [PARAMS]"
    echo "  parameters:"
    echo "   -h    help"
    echo "   -D    device interface"
    echo "   -U    server url"
    echo "   -P    server port"
    echo "   -N    peer dns"
    echo "   -S    internal subnet"
    echo "   -A    allowed-ips"
    echo "   -K    persistant keep alive (default: false)"
    echo "   -R    path to file with custom iptables or other PostUp/PostDown rules (optional)"
    echo "   -C    enable CoreDNS support (true|false)"
    echo "   -L    list servers"
    echo "   -v    enable verbose (debug) output"
}

while getopts "hD:U:P:N:S:A:K:R:C:Lv" opt; do
    case $opt in
        D) ARG_DEVINT=${OPTARG} ;;
        U) ARG_SERVERURL=${OPTARG} ;;
        P) ARG_SERVERPORT=${OPTARG} ;;
        N) ARG_PEERDNS=${OPTARG} ;;
        S) ARG_INTERNAL_SUBNET=${OPTARG} ;;
        A) ARG_ALLOWEDIPS=${OPTARG} ;;
        K) ARG_PERSISTENT_KEEPALIVE=${OPTARG} ;;
        R) ARG_CUSTOM_RULES_FILE=${OPTARG} ;;
        C) ARG_USE_COREDNS=$(normalize_bool "${OPTARG}") ;;
        L) list_servers ;;
        v) ARG_VERBOSE=true ;;  # Enable verbose/debug output
        h | *) usage; exit 0 ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
    esac
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# VALIDATION
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ -z "$ARG_DEVINT" ]]; then
    echo "**** [ERROR] -D (DEVINT) parameter is required. Use -h for help. ****"
    exit 1
fi

# ─── Resolve SERVER_DIR
SERVER_DIR="/config/server_${ARG_DEVINT}"

# ─── Load Server-Specific Configuration if Available
if [[ -f "$SERVER_DIR/settings.env" ]]; then
    source "$SERVER_DIR/settings.env"
    debug "**** [INFO] Loaded server-specific settings from $SERVER_DIR/settings.env ****"
else
    debug "**** [INFO] No server-specific settings found for $ARG_DEVINT. Using global settings. ****"
fi

WG_CONF_FILE="/config/wg_confs/${ARG_DEVINT}.conf"

if [[ -f "$WG_CONF_FILE" ]]; then
    debug "**** [INFO] Server config already exists for ${ARG_DEVINT} at ${WG_CONF_FILE}. Skipping. ****"
    exit 0
fi

if [[ -d "$SERVER_DIR" ]]; then
    # Allow directory if it only contains settings.env
    if [[ "$(ls -A "$SERVER_DIR" | grep -v 'settings.env')" ]]; then
        echo "**** [ERROR] Server directory already exists for device ${ARG_DEVINT} at ${SERVER_DIR} and contains other files. Abort. ****"
        exit 1
    else
        debug "**** [INFO] Server directory exists but only contains settings.env. Proceeding with server setup. ****"
    fi
fi

# ─── Resolve Arguments Using Fallbacks
ARG_SERVERURL=$(resolve_arg "$ARG_SERVERURL" "GWExternalServerUrl" "auto")
ARG_SERVERPORT=$(resolve_arg "$ARG_SERVERPORT" "GWExternalServerPort" "51820")
ARG_INTERNAL_SUBNET=$(resolve_arg "$ARG_INTERNAL_SUBNET" "GWContainerWGSubnet" "10.13.13.0")
ARG_ALLOWEDIPS=$(resolve_arg "$ARG_ALLOWEDIPS" "GWContainerWGAllowedIPs" "0.0.0.0/0")
ARG_PEERDNS=$(resolve_arg "$ARG_PEERDNS" "GWContainerWGPeerDNS" "auto")
ARG_USE_COREDNS=$(normalize_bool "$(resolve_arg "$ARG_USE_COREDNS" "GWUseCoreDNS" "false")")
ARG_PERSISTENT_KEEPALIVE=$(resolve_arg "$ARG_PERSISTENT_KEEPALIVE" "GWContainerWGPersistKeepAlive" "")

# ─── Derived Values
BASE_SUBNET="${ARG_INTERNAL_SUBNET%.*}"  # Remove last octet to get base subnet
GATEWAY_IP="${GWContainerWGGW%/*}"  # Exclude CIDR from gateway IP

if [[ "$ARG_SERVERURL" == "auto" ]]; then
    ARG_SERVERURL=$(curl -s icanhazip.com)
    debug "**** [INFO] Auto-detected external IP: $ARG_SERVERURL ****"
fi

if [[ "$ARG_PEERDNS" == "auto" ]]; then
    ARG_PEERDNS="${BASE_SUBNET}.1"
    debug "**** [INFO] Auto-set Peer DNS to $ARG_PEERDNS ****"
fi

echo "**** [INFO] Server Config:"
echo "   Interface       : $ARG_DEVINT"
echo "   External URL    : $ARG_SERVERURL"
echo "   External Port   : $ARG_SERVERPORT"
echo "   Internal Subnet : $ARG_INTERNAL_SUBNET"
echo "   Allowed IPs     : $ARG_ALLOWEDIPS"
echo "   Peer DNS        : $ARG_PEERDNS"
echo "   CoreDNS Enabled : $ARG_USE_COREDNS"
if is_positive_integer "${ARG_PERSISTENT_KEEPALIVE:-}"; then
    echo "   PersistentKeepalive: ${ARG_PERSISTENT_KEEPALIVE} seconds"
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CREATE DIR
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

mkdir -p "$SERVER_DIR"
debug "**** [SUCCESS] Created server dir: $SERVER_DIR ****"

# ─── CoreDNS Toggle
echo "$ARG_USE_COREDNS" > /run/s6/container_environment/USE_COREDNS

# ─── Key Generation
if [[ ! -f "${SERVER_DIR}/privatekey-server" ]]; then
    umask 077
    wg genkey | tee "${SERVER_DIR}/privatekey-server" | wg pubkey > "${SERVER_DIR}/publickey-server"
    debug "**** [SUCCESS] WireGuard server keys created ****"
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# LOAD server.conf template
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Read and load the server.conf template
TEMPLATE_CONTENT=$(cat /config/templates/server.conf)

# Auto-fix: Remove CIDR suffix (/24, /32 etc) if mistakenly included
TEMPLATE_CONTENT=$(echo "$TEMPLATE_CONTENT" | sed -E 's#^(Address *= *[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/[0-9]+#\1#')

# Read server's generated private key
SERVER_PRIVATE_KEY=$(< "${SERVER_DIR}/privatekey-server")
SERVER_INTERNAL_ADDRESS="${GWContainerWGGW}"
SERVER_INTERNAL_PORT=${GWContainerWGPort:-51820}

# Handle optional custom user rules
USER_CUSTOM_RULES=""
if [[ -n "${ARG_CUSTOM_RULES_FILE:-}" && -f "${ARG_CUSTOM_RULES_FILE}" ]]; then
    USER_CUSTOM_RULES=$(cat "${ARG_CUSTOM_RULES_FILE}")
    debug "**** [INFO] Loaded custom user rules from ${ARG_CUSTOM_RULES_FILE} ****"
fi

# Perform variable substitutions
FINAL_TEMPLATE=$(echo "$TEMPLATE_CONTENT" | \
    sed "s|\${SERVER_PRIVATE_KEY}|${SERVER_PRIVATE_KEY}|g" | \
    sed "s|\${SERVER_INTERNAL_ADDRESS}|${SERVER_INTERNAL_ADDRESS}|g" | \
    sed "s|\${SERVER_INTERNAL_PORT}|${SERVER_INTERNAL_PORT}|g" | \
    sed "s|<USER_CUSTOM_RULES>|${USER_CUSTOM_RULES}|g")

# Write final server WireGuard config
echo "$FINAL_TEMPLATE" > "$WG_CONF_FILE"

debug "**** [SUCCESS] WireGuard server config created at $WG_CONF_FILE ****"

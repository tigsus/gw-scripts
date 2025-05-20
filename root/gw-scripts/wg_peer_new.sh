#!/bin/bash

set -euo pipefail

BASH_DIRNAME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize arguments
ARG_DEVINT=""
ARG_PEER=""
ARG_IP=""
ARG_CLIENT_ALLOWED_IPS=""
ARG_PERSISTENT_KEEPALIVE=""
ARG_VERBOSE=false
ARG_USE_COREDNS=false

ARG_USERMODE=true
ARG_USERMODE_FORMAT="json"
ARG_USER_ID=""
ARG_USER_DEVICENAME=""
ARG_USER_INTERNALDEVICEID=""
ARG_USER_ISDISABLED=false

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Functions
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]
}

debug() {
    if $ARG_VERBOSE; then
        echo "[DEBUG] $1"
    fi
}

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

usage() {
    echo "Usage: $0 -D <DEVINT> -p <PEER> [options]"
    echo
    echo "Required:"
    echo "  -D    WireGuard device interface (e.g. wg0)"
    echo "  -p    Peer ID (e.g. peer1)"
    echo
    echo "Options:"
    echo "  -i    Peer IP address (optional)"
    echo "  -a    Client allowed IPs/subnets (optional)"
    echo "  -K    PersistentKeepalive seconds (integer)"
    echo "  -v    Verbose output (debugging)"
    echo
    echo "User device fields (if -u true):"
    echo "  -u    User mode (true/false, default=true)"
    echo "  -f    User format (json/conf, default=json)"
    echo "  -U    User ID (email)"
    echo "  -N    Device name"
    echo "  -I    Internal device ID"
    echo "  -d    Disable peer immediately (true/false)"
}

while getopts "hD:p:i:a:K:u:f:U:N:I:d:v" opt; do
    case $opt in
        D) ARG_DEVINT="${OPTARG}" ;;
        p) ARG_PEER="${OPTARG}" ;;
        i) ARG_IP="${OPTARG}" ;;
        a) ARG_CLIENT_ALLOWED_IPS="${OPTARG}" ;;
        K) ARG_PERSISTENT_KEEPALIVE="${OPTARG}" ;;
        u) ARG_USERMODE="${OPTARG,,}" ;;
        f) ARG_USERMODE_FORMAT="${OPTARG,,}" ;;
        U) ARG_USER_ID="${OPTARG}" ;;
        N) ARG_USER_DEVICENAME="${OPTARG}" ;;
        I) ARG_USER_INTERNALDEVICEID="${OPTARG}" ;;
        d) ARG_USER_ISDISABLED="${OPTARG,,}" ;;
        v) ARG_VERBOSE=true ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# VALIDATIONS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ -z "$ARG_DEVINT" ]]; then
    echo "Error: Parameter -D (DEVINT) is required." >&2
    exit 1
fi

if [[ -z "$ARG_PEER" ]]; then
    echo "Error: Parameter -p (PEER) is required." >&2
    exit 1
fi

WG_CONF_FILE="/config/wg_confs/${ARG_DEVINT}.conf"
SERVER_DIR="/config/server_${ARG_DEVINT}"

# Check if WireGuard config and server directory exist
if [[ ! -f "$WG_CONF_FILE" ]]; then
    echo "Error: wg_conf file not found at ${WG_CONF_FILE}" >&2
    exit 1
fi

if [[ ! -d "$SERVER_DIR" ]]; then
    echo "Error: server directory not found at ${SERVER_DIR}" >&2
    exit 1
fi

# Check if the server directory contains required files
required_files=("privatekey-server" "publickey-server")
missing_files=()

for file in "${required_files[@]}"; do
    if [[ ! -f "$SERVER_DIR/$file" ]]; then
        missing_files+=("$file")
    fi
done

# If any required files are missing, exit with an error
if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo "Error: Missing required files in server directory ${SERVER_DIR}: ${missing_files[@]}" >&2
    exit 1
fi

# ─── Load Global Configuration
if [[ -f /gw-scripts/globals.env ]]; then
    source /gw-scripts/globals.env
else
    echo "**** [ERROR] globals.env not found at /gw-scripts/globals.env. Aborting. ****"
    exit 1
fi

# ─── Load Server Settings from settings.env if it exists
if [[ -f "$SERVER_DIR/settings.env" ]]; then
    source "$SERVER_DIR/settings.env"
    debug "Loaded server-specific settings from $SERVER_DIR/settings.env"
else
    debug "No server-specific settings found for $ARG_DEVINT. Using global settings."
fi

# ─── Resolve Arguments Using Fallbacks (Combine with Environment Variables)
ARG_SERVERURL="${ARG_SERVERURL:-$GWExternalServerUrl}"
ARG_SERVERPORT="${ARG_SERVERPORT:-$GWExternalServerPort}"
ARG_INTERNAL_SUBNET="${ARG_INTERNAL_SUBNET:-$GWContainerWGSubnet}"
ARG_ALLOWEDIPS="${ARG_ALLOWEDIPS:-$GWContainerWGAllowedIPs}"
ARG_PEERDNS="${ARG_PEERDNS:-$GWContainerWGPeerDNS}"
ARG_USE_COREDNS="${ARG_USE_COREDNS:-$GWUseCoreDNS}"
ARG_PERSISTENT_KEEPALIVE="${ARG_PERSISTENT_KEEPALIVE:-$GWContainerWGPersistKeepAlive}"

# ─── Derived Values (BASE_SUBNET and GATEWAY_IP)
BASE_SUBNET="${ARG_INTERNAL_SUBNET%.*}"  # Remove last octet to get base subnet
GATEWAY_IP="${GWContainerWGGW%/*}"  # Exclude CIDR from gateway IP

debug "Server settings loaded: SERVERURL=$ARG_SERVERURL, SERVERPORT=$ARG_SERVERPORT, INTERNAL_SUBNET=$ARG_INTERNAL_SUBNET, BASE_SUBNET=$BASE_SUBNET"

# ─── PeerDNS checks
if [[ -z "$ARG_PEERDNS" ]] || [[ "$ARG_PEERDNS" == "auto" ]]; then
    ARG_PEERDNS="${GATEWAY_IP}"  # Use gateway IP as default DNS
    echo "PEERDNS is either not set or set to \"auto\", setting peer DNS to ${GATEWAY_IP} (gateway address) for DNS resolution."
else
    debug "Peer DNS servers will be set to $PEERDNS"
fi

# ─── User Mode Validations
if [[ "$ARG_USERMODE" == "true" && -z "$ARG_USER_ID" ]]; then
    echo "Error: -U (USER_ID) is required when user mode is enabled." >&2
    exit 1
fi

# ─── Prepare Peer Directory
[[ "$ARG_PEER" != peer_* ]] && ARG_PEER="peer_$ARG_PEER"
PEER_DIR="${SERVER_DIR}/${ARG_PEER}"

debug "Checking if peer directory already exists at $PEER_DIR"

if [[ -d "$PEER_DIR" ]]; then
    echo "Error: Peer $ARG_PEER already exists at ${PEER_DIR}" >&2
    exit 1
fi

mkdir -p "$PEER_DIR"
debug "Created directory for peer $ARG_PEER."

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# LOGIC
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# ─── IP Discovery
if [[ -z "$ARG_IP" ]]; then
    debug "No IP provided, discovering available IP."

    # Initialize USED_IPS as empty
    USED_IPS=""
    
    # Loop through each peer configuration file and extract IP addresses
    for peer_conf in ${SERVER_DIR}/peer_*/peer_*.conf; do
        if [[ -f "$peer_conf" ]]; then
            # Extract the IP address assigned to this peer
            peer_ip=$(grep -oP "Address\s*=\s*\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" "$peer_conf" 2>/dev/null)
            if [[ -n "$peer_ip" ]]; then
                USED_IPS="$USED_IPS $peer_ip"
                debug "Found used IP: $peer_ip in $peer_conf"
            fi
        fi
    done

    debug "Used IPs: $USED_IPS"
    
    # Loop to find the next available IP
    for idx in {2..254}; do
        PROPOSED_IP="${BASE_SUBNET}.${idx}"
        debug "Checking if proposed IP $PROPOSED_IP is in use."
        
        if ! echo "$USED_IPS" | grep -q "$PROPOSED_IP"; then
            ARG_IP="$PROPOSED_IP"
            debug "Assigned IP: $ARG_IP"
            break
        fi
    done

    if [[ -z "$ARG_IP" ]]; then
        echo "Error: No available IP addresses in range ${BASE_SUBNET}.2 - ${BASE_SUBNET}.254."
        exit 1
    fi
fi

is_valid_ip() {
    local ip="$1"
    local stat=1

    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi

    return $stat
}

if ! is_valid_ip "$ARG_IP"; then
    echo "The IP address could not be detected or is invalid. We tried '$ARG_IP'."
    exit 1
fi

# ─── Generate Keys
if [[ ! -f "${PEER_DIR}/privatekey-${ARG_PEER}" ]]; then
    umask 077
    wg genkey | tee "${PEER_DIR}/privatekey-${ARG_PEER}" | wg pubkey > "${PEER_DIR}/publickey-${ARG_PEER}"
    wg genpsk > "${PEER_DIR}/presharedkey-${ARG_PEER}"
    debug "Generated private/public/preshared keys for $ARG_PEER."
fi

# ─── Render Peer Conf Template

# Ensure CLIENT_IP and PEER_ID are set correctly
CLIENT_IP="${ARG_IP:-auto}"
PEER_ID="${ARG_PEER}"

# Load the peer.conf template
TEMPLATE_CONTENT=$(< /config/templates/peer.conf)

# Dynamically load the key values
PRIVATE_KEY=$(< "/config/server_${ARG_DEVINT}/${PEER_ID}/privatekey-${PEER_ID}")
PUBLIC_KEY=$(< "/config/server_${ARG_DEVINT}/publickey-server")
PRESHARED_KEY=$(< "/config/server_${ARG_DEVINT}/${PEER_ID}/presharedkey-${PEER_ID}")
SERVER_INTERNAL_PORT=${GWContainerWGPort:-51820}
# Default to `0.0.0.0/0` for ALLOWED_IPS.
# Why not ipv6? `::/0` => breaks docker clients if not built with ipv6 / ip6tables
# Why not "" (empty)? "" => not allowed on docker clients
# Why not remove the property if empty? => not allowed on docker clients
ALLOWED_IPS="${ARG_CLIENT_ALLOWED_IPS:-0.0.0.0/0}"

debug "Rendering peer configuration with IP: $CLIENT_IP, Allowed IPs: $ALLOWED_IPS"

# Safely render the template with variable substitution
RENDERED_PEER_CONF=$(echo "$TEMPLATE_CONTENT" | sed -e "
  s|\${CLIENT_IP}|${CLIENT_IP}|g
  s|\${PEER_ID}|${PEER_ID}|g
  s|\${SERVERURL}|${ARG_SERVERURL}|g
  s|\${SERVERPORT}|${ARG_SERVERPORT}|g
  s|\${SERVER_INTERNAL_PORT}|${SERVER_INTERNAL_PORT}|g
  s|\${PEERDNS}|${ARG_PEERDNS}|g
  s|\${ALLOWEDIPS}|${ALLOWED_IPS}|g
  s|\${PRIVATE_KEY}|${PRIVATE_KEY}|g
  s|\${PUBLIC_KEY}|${PUBLIC_KEY}|g
  s|\${PRESHARED_KEY}|${PRESHARED_KEY}|g
")

echo "$RENDERED_PEER_CONF" > "${PEER_DIR}/${ARG_PEER}.conf"
debug "Rendered peer config saved to ${PEER_DIR}/${ARG_PEER}.conf"

# ─── Update Server Conf
{
  echo "# BEGIN $ARG_PEER"
  echo "[Peer]"
  echo "PublicKey = $(< "${PEER_DIR}/publickey-${ARG_PEER}")"
  echo "PresharedKey = $(< "${PEER_DIR}/presharedkey-${ARG_PEER}")"
  echo "AllowedIPs = ${ARG_IP}/32"
  if is_positive_integer "$ARG_PERSISTENT_KEEPALIVE"; then
      echo "PersistentKeepalive = ${ARG_PERSISTENT_KEEPALIVE}"
  fi
  echo "# END $ARG_PEER"
  echo ""
} >> "${WG_CONF_FILE}"

debug "Updated server config at ${WG_CONF_FILE}"

# ─── Generate QR Codes
if command -v qrencode >/dev/null 2>&1; then
    qrencode -o "${PEER_DIR}/${ARG_PEER}.png" < "${PEER_DIR}/${ARG_PEER}.conf"
    debug "Generated QR code at ${PEER_DIR}/${ARG_PEER}.png"
else
    echo "Warning: qrencode not installed; QR code not generated." >&2
fi

# ─── Create User Device Config
if [[ "$ARG_USERMODE" == "true" ]]; then
    if [[ "$ARG_USERMODE_FORMAT" == "json" ]]; then
        cat <<EOF > "${PEER_DIR}/user-device.json"
{
  "userId": "${ARG_USER_ID}",
  "name": "${ARG_USER_DEVICENAME}",
  "internalId": "${ARG_USER_INTERNALDEVICEID}",
  "disabled": ${ARG_USER_ISDISABLED},
  "wgPeerId": "${ARG_PEER}",
  "clientIP": "${ARG_IP}"
}
EOF
        debug "Created user-device.json."
    else
        cat <<EOF > "${PEER_DIR}/user-device.conf"
USERID="${ARG_USER_ID}"
NAME="${ARG_USER_DEVICENAME}"
INTERNALID="${ARG_USER_INTERNALDEVICEID}"
DISABLED=${ARG_USER_ISDISABLED}
WGPEERID="${ARG_PEER}"
CLIENTIP="${ARG_IP}"
EOF
        debug "Created user-device.conf."
    fi

    if [[ "$ARG_USER_ISDISABLED" == "true" ]]; then
        if ! "${BASH_SOURCE%/*}/wg_peer_disable.sh" -D "$ARG_DEVINT" -p "$ARG_PEER"; then
            echo "Error: Failed to disable peer $ARG_PEER." >&2
            exit 2
        fi
    fi
fi

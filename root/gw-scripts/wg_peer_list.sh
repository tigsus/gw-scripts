#!/bin/bash

#!/bin/bash
set -e

ARG_DEVINT=""
ARG_USER_ID=""
ARG_FILE=""
ARG_PEER=""
ARG_IP=""

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

usage() {
    echo "Usage: $0 -D <DEVINT> [-U <USER_ID>] [-F <FILE>] [-p <PEER>] [-i <IP>]"
    echo "  Parameters:"
    echo "   -h    Help"
    echo "   -D    WireGuard device interface (required)"
    echo "   -p    Peer ID (required if requesting a file)"
    echo "   -U    Filter by User ID (optional)"
    echo "   -i    Filter by IP Address (optional)"
    echo "   -F    File type (json | conf | png), default: json"
    echo
    echo "Examples:"
    echo "  $0 -D wg0"
    echo "  $0 -D wg0 -p peer_1 -F conf"
    echo "  $0 -D wg0 -U user@example.com"
    echo "  $0 -D wg0 -i 192.168.0.1"
}

while getopts "hD:U:F:p:i:" opt; do
    case $opt in
        D) ARG_DEVINT=${OPTARG} ;;
        U) ARG_USER_ID=${OPTARG} ;;
        F) ARG_FILE=${OPTARG} ;;
        p) ARG_PEER=${OPTARG} ;;
        i) ARG_IP=${OPTARG} ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# PREREQUISITES
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed." >&2
    exit 1
fi

if [[ -z "$ARG_DEVINT" ]]; then
    echo "Error: Parameter -D (DEVINT) is required. Use -h for help." >&2
    exit 1
fi

WG_CONF_FILE="/config/wg_confs/${ARG_DEVINT}.conf"
SERVER_DIR="/config/server_${ARG_DEVINT}"

if [[ ! -f "$WG_CONF_FILE" ]]; then
    echo "Error: WireGuard config file not found at $WG_CONF_FILE" >&2
    exit 1
fi

if [[ ! -d "$SERVER_DIR" ]]; then
    echo "Error: Server directory not found at $SERVER_DIR" >&2
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# LOGIC
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# ─── Default File Type
ARG_FILE=${ARG_FILE:-json}

# ─── Serve Specific Peer File if Requested
if [[ -n "$ARG_PEER" ]]; then
    if [[ "$ARG_PEER" != peer_* ]]; then
        ARG_PEER="peer_${ARG_PEER}"
    fi

    if [[ "$ARG_FILE" != "conf" && "$ARG_FILE" != "png" ]]; then
        ARG_FILE="json"
        ARG_FILE_PATH="${SERVER_DIR}/${ARG_PEER}/user-device.${ARG_FILE}"
    else
        ARG_FILE_PATH="${SERVER_DIR}/${ARG_PEER}/${ARG_PEER}.${ARG_FILE}"
    fi

    if [[ ! -f "$ARG_FILE_PATH" ]]; then
        echo "Error: Requested file not found: $ARG_FILE_PATH" >&2
        exit 1
    fi

    if [[ "$ARG_FILE" == "png" ]]; then
        cat "$ARG_FILE_PATH"
    else
        cat "$ARG_FILE_PATH"
    fi
    exit 0
fi

# ─── Collect Peers for JSON Output
PEERS=()

for PEER_DIR in "${SERVER_DIR}"/peer_*; do
    [[ -d "$PEER_DIR" ]] || continue

    DEVJSON_FILE="${PEER_DIR}/user-device.json"
    if [[ -f "$DEVJSON_FILE" ]]; then
        user_id=$(jq -r '.userId // empty' "$DEVJSON_FILE")
        client_ip=$(jq -r '.clientIP // empty' "$DEVJSON_FILE")

        match=true

        if [[ -n "$ARG_USER_ID" ]]; then
            [[ "${user_id,,}" == "${ARG_USER_ID,,}" ]] || match=false
        fi

        if [[ "$match" == true && -n "$ARG_IP" ]]; then
            [[ "${client_ip,,}" == "${ARG_IP,,}" ]] || match=false
        fi

        if [[ "$match" == true ]]; then
            PEERS+=("$(cat "$DEVJSON_FILE")")
        fi
    fi
done

# ─── Output Final JSON Array
if [[ ${#PEERS[@]} -eq 0 ]]; then
    echo "[]" # Empty array if no matches
else
    printf '%s\n' "${PEERS[@]}" | jq -s '.'
fi

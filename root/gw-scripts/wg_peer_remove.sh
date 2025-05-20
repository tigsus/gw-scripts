#!/bin/bash

set -e

ARG_DEVINT=""
ARG_PEER=""
ARG_USER_ID=""

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

usage() {
    echo "Usage: $0 -D <DEVINT> -p <PEER> [-U <USER_ID>]"
    echo "  Parameters:"
    echo "   -h    Help"
    echo "   -D    Device interface (required)"
    echo "   -p    Peer ID (optional if -U used)"
    echo "   -U    User ID (optional if -p used)"
}

while getopts "hp:D:U:" opt; do
  case $opt in
    D) ARG_DEVINT=${OPTARG} ;;
    p) ARG_PEER=${OPTARG} ;;
    U) ARG_USER_ID=${OPTARG} ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# VALIDATIONS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ -z "$ARG_DEVINT" ]]; then
    echo "Error: -D (DEVINT) is required." >&2
    exit 1
fi

WG_CONF_FILE="/config/wg_confs/${ARG_DEVINT}.conf"
SERVER_DIR="/config/server_${ARG_DEVINT}"

if [[ ! -f "$WG_CONF_FILE" ]]; then
    echo "Error: WireGuard config not found at $WG_CONF_FILE" >&2
    exit 1
fi

if [[ ! -d "$SERVER_DIR" ]]; then
    echo "Error: Server directory not found at $SERVER_DIR" >&2
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# FIND PEERS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Function to check if user-device.json contains the userId
contains_userId() {
    local file="$1"
    jq --exit-status ".userId == \"$ARG_USER_ID\"" "$file" > /dev/null 2>&1
}

PEER_ARRAY=()

if [[ -z "$ARG_PEER" ]]; then
    if [[ -n "$ARG_USER_ID" ]]; then
        while IFS= read -r -d '' file; do
            dir=$(dirname "$file")
            if contains_userId "$file"; then
                PEER_ARRAY+=("$dir")
            fi
        done < <(find "$SERVER_DIR"/peer_* -type f -name "user-device.json" -print0)
    fi
else
    [[ "$ARG_PEER" != peer_* ]] && ARG_PEER="peer_$ARG_PEER"
    PEER_DIR="$SERVER_DIR/$ARG_PEER"

    if [[ ! -d "$PEER_DIR" ]]; then
        echo "Error: Peer directory $PEER_DIR not found." >&2
        exit 1
    fi

    PEER_ARRAY+=("$PEER_DIR")
fi

if [[ ${#PEER_ARRAY[@]} -eq 0 ]]; then
    echo "Error: No matching peer(s) found. Use -h for help." >&2
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# REMOVE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# ─── Remove Peers
for dir in "${PEER_ARRAY[@]}"; do
    peerid=$(basename "$dir")

    echo "Removing peer: $peerid"

    # Safely remove peer directory if exists
    if [[ -d "$dir" ]]; then
        rm -rf "$dir"
        echo "Success: removed directory $dir"
    else
        echo "Notice: directory $dir already removed."
    fi

    # Remove config block
    if sed -i "/# BEGIN $peerid/,/# END $peerid/d" "$WG_CONF_FILE"; then
        echo "Success: removed config block for $peerid from $WG_CONF_FILE"
    else
        echo "Warning: config block for $peerid not found in $WG_CONF_FILE"
    fi
done

# ─── Final cleanup: collapse empty lines
if sed -i '/^$/N;/\n$/D' "$WG_CONF_FILE"; then
    echo "Success: cleaned up empty lines in $WG_CONF_FILE"
fi

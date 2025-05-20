#!/bin/bash

set -e

ARG_DEVINT=""
ARG_PEER=""

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

usage() {
    echo "Usage: $0 -D <DEVINT> -p <PEER>"
    echo "  Parameters:"
    echo "   -h    Help"
    echo "   -D    Device interface"
    echo "   -p    Peer ID"
}

while getopts "hp:D:" opt; do
  case $opt in
    D) ARG_DEVINT=${OPTARG} ;;
    p) ARG_PEER=${OPTARG} ;;
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

if [[ -z "$ARG_PEER" ]]; then
    echo "Error: -p (PEER) is required." >&2
    exit 1
fi

[[ "$ARG_PEER" != peer_* ]] && ARG_PEER="peer_$ARG_PEER"
PEER_DIR="$SERVER_DIR/$ARG_PEER"

if [[ ! -d "$PEER_DIR" ]]; then
    echo "Error: Peer directory $PEER_DIR does not exist." >&2
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ENABLE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

DISABLED_FILE="$PEER_DIR/disabled.conf"

if [[ ! -f "$DISABLED_FILE" ]]; then
    echo "Error: disabled file not found at $DISABLED_FILE" >&2
    exit 1
fi

if cat "$DISABLED_FILE" >> "$WG_CONF_FILE"; then
    echo "Success: appended disabled block back into $WG_CONF_FILE"
else
    echo "Error: failed appending $DISABLED_FILE into $WG_CONF_FILE" >&2
    exit 1
fi

# Add empty line for neatness
echo "" >> "$WG_CONF_FILE"

# ─── Collapse Empty Lines
if sed -i '/^$/N;/\n$/D' "$WG_CONF_FILE"; then
    echo "Success: cleaned up empty lines in $WG_CONF_FILE"
fi

# ─── Validate Re-Addition
EXTRACTED_TEXT=$(sed -n "/# BEGIN $ARG_PEER/,/# END $ARG_PEER/p" "$WG_CONF_FILE")

if [[ -z "$EXTRACTED_TEXT" ]]; then
    echo "Error: After enabling, block for $ARG_PEER not found in $WG_CONF_FILE" >&2
    exit 1
else
    echo "Success: block for $ARG_PEER confirmed in $WG_CONF_FILE"
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# REMOVE DISABLED FILE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if rm -f "$DISABLED_FILE"; then
    echo "Success: removed disabled file $DISABLED_FILE"
else
    echo "Error: failed to remove $DISABLED_FILE" >&2
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# UPDATE USER-DEVICE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

FILE_USERDEVICE="$PEER_DIR/user-device.conf"
if [[ -f "$FILE_USERDEVICE" ]]; then
    if sed -i "s/^DISABLED=.*/DISABLED=false/" "$FILE_USERDEVICE"; then
        echo "Success: updated DISABLED=false in $FILE_USERDEVICE"
    else
        echo "Error: failed updating $FILE_USERDEVICE" >&2
        exit 1
    fi
else
    FILE_USERDEVICE="$PEER_DIR/user-device.json"
    if [[ -f "$FILE_USERDEVICE" ]]; then
        TMP_JSON="$PEER_DIR/temp-user-device.json"
        if jq '.disabled = false' "$FILE_USERDEVICE" > "$TMP_JSON"; then
            if mv "$TMP_JSON" "$FILE_USERDEVICE"; then
                echo "Success: updated DISABLED=false in $FILE_USERDEVICE"
            else
                echo "Error: failed to move updated $FILE_USERDEVICE" >&2
                exit 1
            fi
        else
            echo "Error: jq failed modifying $FILE_USERDEVICE" >&2
            rm -f "$TMP_JSON"
            exit 1
        fi
    fi
fi

exit 0

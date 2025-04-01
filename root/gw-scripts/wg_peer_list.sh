#!/bin/bash

# Function to get the directory of the script
get_dirname() {
    filename="${BASH_SOURCE[0]}"
    dirname=$(dirname "$filename")
    dirname="${dirname:-./}"
    if ! [ -d "$dirname" ]; then
        echo "The directory is not valid." >&2
        exit 1
    fi
    BASH_DIRNAME="$dirname"
}

get_dirname

ARG_DEVINT=
ARG_USER_ID=
ARG_FILE=
ARG_PEER=
ARG_IP=

# Check for jq
if ! command -v jq &>/dev/null; then
    echo "jq is required but not installed. Please install jq and try again." >&2
    exit 1
fi

# CLI usage
function usage {
    echo "Usage: $0 -D <DEVINT> -U <USER_ID> -F <FILE> -p <PEER>"
    echo "  parameters:"
    echo "   -h    help"
    echo "   -D    device interface"
    echo "   -p    peer ID (required for -F conf or -F png)"
    echo "   -U    filter on user id"
    echo "   -i    filter on IP address"
    echo "   -F    file type (json | conf | png) default=json"
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
        h | *) usage; exit 0 ;;
    esac
done

# Validate ARG_DEVINT
if [[ -z "$ARG_DEVINT" ]]; then
    echo "Parameter -D (DEVINT) is required. Use -h for help."
    exit 1
fi

WG_CONF_FILE="/config/wg_confs/${ARG_DEVINT}.conf"
if [[ ! -f "$WG_CONF_FILE" ]]; then
    echo "failed: wg_conf file not found for device interface ${ARG_DEVINT} at ${WG_CONF_FILE}"
    exit 1
fi

SERVER_DIR="/config/server_${ARG_DEVINT}"
if [[ ! -d "$SERVER_DIR" ]]; then
    echo "failed: server directory not found for device interface ${ARG_DEVINT} at ${SERVER_DIR}"
    exit 1
fi

ARG_FILE=${ARG_FILE:-json}

if [[ -n "$ARG_PEER" ]]; then
    # Add the "peer_" prefix to ARG_PEER if it doesn't already have it
    if [[ "$ARG_PEER" != peer_* ]]; then
        ARG_PEER="peer_${ARG_PEER}"
    fi

    # Determine the file path based on the type of file requested
    if [[ "$ARG_FILE" != "conf" && "$ARG_FILE" != "png" ]]; then
        ARG_FILE="json"
        ARG_FILE_PATH="${SERVER_DIR}/${ARG_PEER}/user-device.${ARG_FILE}"
    else
        ARG_FILE_PATH="${SERVER_DIR}/${ARG_PEER}/${ARG_PEER}.${ARG_FILE}"
    fi

    # Check if the file exists
    if [[ ! -f "$ARG_FILE_PATH" ]]; then
        echo "failed: file not found ${ARG_FILE_PATH}" >&2
        exit 1
    fi

    # Serve the file content for Docker output
    if [[ "$ARG_FILE" = "png" ]]; then
        # Binary file output (e.g., for Docker)
        echo "Serving binary file: $ARG_FILE_PATH" >&2
        cat "$ARG_FILE_PATH"
    else
        # Text-based file output
        echo "Serving text file: $ARG_FILE_PATH" >&2
        cat "$ARG_FILE_PATH"
    fi
    exit 0
fi

# Initialize PEERS array
PEERS=()

# Loop through peer directories
for PEER_DIR in ${SERVER_DIR}/peer_*; do
    if [[ -d "$PEER_DIR" ]]; then
        DEVJSON_FILE="$PEER_DIR/user-device.json"
        if [[ -f "$DEVJSON_FILE" ]]; then
            USER_ID=$(jq -r '.userId' "$DEVJSON_FILE")
            if [[ -n "$ARG_USER_ID" ]] && [[ "${USER_ID,,}" != "${ARG_USER_ID,,}" ]]; then
                continue
            fi
            CLIENT_IP=$(jq -r '.clientIP' "$DEVJSON_FILE")
            if [[ -n "$ARG_IP" ]] && [[ "${CLIENT_IP,,}" != "${ARG_IP,,}" ]]; then
                continue
            fi
            PEERS+=("$(cat "$DEVJSON_FILE")")
        fi
    fi
done

# Print JSON array
if [[ ${#PEERS[@]} -eq 0 ]]; then
    echo "[]" # Empty JSON array
else
    printf '%s\n' "${PEERS[@]}" | jq -s '.'
fi

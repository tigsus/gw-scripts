#!/bin/bash

set -e

ARG_DEVINT=""

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

usage() {
    echo "Usage: $0 -D <DEVICE_INTERFACE>"
    echo "  Parameters:"
    echo "   -h    Help"
    echo "   -D    WireGuard device interface (optional; if omitted, attempts to stop all found interfaces)"
}

while getopts "hD:" opt; do
  case $opt in
    D) ARG_DEVINT=${OPTARG} ;;
    h | *) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
  esac
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# LOGIC
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

CONFIG_BASE="/config/server_"

if [[ -n "$ARG_DEVINT" ]]; then
    echo "----> Attempting to bring down interface: $ARG_DEVINT"
    if wg-quick down "$ARG_DEVINT"; then
        echo "**** [SUCCESS] Interface $ARG_DEVINT brought down manually. ****"
    else
        echo "**** [ERROR] Failed to bring down interface $ARG_DEVINT. ****"
        exit 1
    fi
else
    echo "**** [INFO] No specific interface provided, attempting full service shutdown. ****"

    if s6-rc -d change svc-wireguard; then
        echo "**** [SUCCESS] WireGuard service stopped successfully via s6-rc. ****"
        exit 0
    fi

    echo "**** [WARN] s6-rc failed to stop svc-wireguard. Attempting manual shutdown of all interfaces. ****"

    FOUND=false
    for SERVER_DIR in ${CONFIG_BASE}*; do
        if [[ -d "$SERVER_DIR" ]]; then
            DEVINT=$(basename "$SERVER_DIR" | sed 's/^server_//')
            if [[ -n "$DEVINT" ]]; then
                FOUND=true
                echo "----> Attempting to bring down interface: $DEVINT"
                if wg-quick down "$DEVINT"; then
                    echo "    [OK] Interface $DEVINT brought down."
                else
                    echo "    [FAIL] Interface $DEVINT could not be brought down."
                fi
            fi
        fi
    done

    if [[ "$FOUND" == false ]]; then
        echo "**** [WARN] No server directories found under ${CONFIG_BASE}*. Nothing to do. ****"
    fi
fi

echo "**** [COMPLETE] WireGuard shutdown operation complete. ****"
exit 0

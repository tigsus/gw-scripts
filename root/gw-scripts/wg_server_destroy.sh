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
    echo "   -D    WireGuard device interface to remove (e.g., wg0)"
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
# VALIDATION
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ -z "$ARG_DEVINT" ]]; then
    echo "**** [ERROR] -D (DEVICE_INTERFACE) is required. Use -h for help. ****"
    exit 1
fi

WG_CONF_FILE="/config/wg_confs/${ARG_DEVINT}.conf"
SERVER_DIR="/config/server_${ARG_DEVINT}"

# ─── Check if Interface Is Active ─────────────────────────────────────────────
IS_WG_ACTIVE=false
if ip link show "$ARG_DEVINT" 2>/dev/null | grep -q "state UP"; then
    IS_WG_ACTIVE=true
    echo "**** [INFO] Interface $ARG_DEVINT is UP — initiating shutdown before removal ****"
    /gw-scripts/wg_down.sh -D "$ARG_DEVINT"
fi

# ─── Remove WireGuard Config ──────────────────────────────────────────────────
if [[ -f "$WG_CONF_FILE" ]]; then
    rm "$WG_CONF_FILE"
    echo "**** [INFO] Removed WireGuard config: $WG_CONF_FILE ****"
else
    echo "**** [WARN] WireGuard config file not found at $WG_CONF_FILE ****"
fi

# ─── Remove Server Directory ──────────────────────────────────────────────────
if [[ -d "$SERVER_DIR" ]]; then
    rm -r "$SERVER_DIR"
    echo "**** [INFO] Removed server directory: $SERVER_DIR ****"
else
    echo "**** [WARN] Server directory not found at $SERVER_DIR ****"
fi

echo "**** [COMPLETE] Removal process for interface $ARG_DEVINT complete. ****"

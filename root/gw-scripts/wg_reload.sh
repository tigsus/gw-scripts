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
    echo "   -D    WireGuard device interface (e.g., wg0)"
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

# Check if ARG_DEVINT is empty string
if [[ -z "$ARG_DEVINT" ]]; then
    echo "**** [ERROR] -D (DEVICE_INTERFACE) is required. Use -h for help. ****"
    exit 1
fi

# ─── Reload Interface
echo "**** Reloading WireGuard configuration for interface: $ARG_DEVINT ****"

if wg syncconf "$ARG_DEVINT" <(wg-quick strip "$ARG_DEVINT"); then
    echo "**** [SUCCESS] Reloaded WireGuard interface $ARG_DEVINT without disrupting active sessions. ****"
else
    echo "**** [ERROR] Failed to reload WireGuard interface $ARG_DEVINT. ****"
    exit 1
fi

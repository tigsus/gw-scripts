#!/bin/bash

ARG_DEVINT=""

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function usage {
    echo "Usage: $0 -D <DEVINT> [PARAMS]"
    echo "  parameters:"
    echo "   -h    help"
    echo "   -D    device interface"
}

while getopts "hD:" opt; do
  case $opt in
    D) # device interface
        ARG_DEVINT=${OPTARG}
        ;;
    h | *) # display help
        usage
        exit 0
        ;;
    \?)
        set +x
        echo "Invalid option: -$OPTARG" >&2
        usage
        exit 1
        ;;
    :)
        set +x
        echo "Option -$OPTARG requires an argument." >&2
        usage
        exit 1
        ;;
  esac
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ARG_DEVINT CHECKS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Check if ARG_DEVINT is empty string
if [[ -z "$ARG_DEVINT" ]]; then
    echo "Parameter -I (DEVICE-INTERFACE) is required. Use -h for help."
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ENSURE WG INTERFACE IS DOWN
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Restart WG after removing the interface completely
IS_WG_ACTIVE=false

# Check if the WireGuard interface is up and running
if ip link show "$wg_interface" 2> /dev/null | grep -q "state UP"; then
    IS_WG_ACTIVE=true
    echo "interface $ARG_DEVINT is UP, so will shutdown WG now and restart after removal"
    /gw-scripts/wg_down.sh
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# REMOVE SERVER INTERFACE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

WG_CONF_FILE=/config/wg_confs/${ARG_DEVINT}.conf

# Check if SERVER_FILE is present
if [[ ! -f "${WG_CONF_FILE}" ]]; then
    echo "server wg_conf file not found at ${WG_CONF_FILE}"
else
    rm ${WG_CONF_FILE}
    echo "deleted wg_conf at ${WG_CONF_FILE}"
fi

SERVER_DIR="/config/server_${ARG_DEVINT}"
if [[ -d "${SERVER_DIR}" ]]; then
    rm -r ${SERVER_DIR}
    echo "deleted interface directory at ${SERVER_DIR}"
fi

if [[ "$IS_WG_ACTIVE" = "true" ]]; then
    /gw-scripts/wg_up.sh
fi


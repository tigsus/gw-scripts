#!/bin/bash

ARG_DEVINT=
ARG_PEER=

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function usage {
    echo "Usage: $0 -D <DEVINT> -p <PEER> [PARAMS]"
    echo "  parameters:"
    echo "   -h    help"
    echo "   -D    device interface"
    echo "   -p    peer ID"
}

while getopts "hp:D:" opt; do
  case $opt in
    D) # device interface
        ARG_DEVINT=${OPTARG}
        ;;
    p) # peer name/identifier
        ARG_PEER=${OPTARG}
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
    echo "Parameter -D (DEVINT) is required. Use -h for help."
    exit 1
fi

WG_CONF_FILE=/config/wg_confs/${ARG_DEVINT}.conf
if [[ ! -f "${WG_CONF_FILE}" ]]; then
    echo "failed: wg_conf file not found for device interface ${ARG_DEVINT} at ${WG_CONF_FILE}"
    exit 1
fi

SERVER_DIR="/config/server_${ARG_DEVINT}"
if [[ ! -d "${SERVER_DIR}" ]]; then
    echo "failed: server directory not found for device interface ${ARG_DEVINT} at ${SERVER_DIR}"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ARG_PEER CHECKS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Check if ARG_PEER is empty string
if [[ -z "$ARG_PEER" ]]; then
    echo "Parameter -p (PEER) is required. Use -h for help."
    exit 1
fi

# Ensure ARG_PEER has the prefix "peer_"
if [[ "$ARG_PEER" != peer_* ]]; then
    ARG_PEER="peer_$ARG_PEER"
fi

PEER_DIR=$SERVER_DIR/${ARG_PEER}

# Check if ARG_PEER already has created directory
if [[ ! -d "${PEER_DIR}" ]]; then
    echo "failed to locate ${ARG_PEER} at ${PEER_DIR}"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ENABLE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

DISABLED_FILE=${PEER_DIR}/disabled.conf

# Check if DISABLED_FILE is present; already disabled
if [[ ! -f "${DISABLED_FILE}" ]]; then
    echo "disabled file not found at ${DISABLED_FILE}"
    exit 0
fi

# append
cat $DISABLED_FILE >> $WG_CONF_FILE
# add an empty line
echo "" >> $WG_CONF_FILE

# Check if the operation was successful
if [ $? -eq 0 ]; then
    echo "success: server config block updated at $WG_CONF_FILE"
fi

# Use sed to collapse multiple empty lines into a single empty line
sed -i '/^$/N;/\n$/D' $WG_CONF_FILE

# Check if the operation was successful
if [ $? -eq 0 ]; then
    echo "success: multiple empty lines replaced in $WG_CONF_FILE"
fi

# Double-check server file is correct
# Extract text between # BEGIN and # END markers and save it to a variable
EXTRACTED_TEXT=$(sed -n "/# BEGIN $ARG_PEER/,/# END $ARG_PEER/p" "$WG_CONF_FILE")

# Check if the operation was successful
if [ ! $? -eq 0 ]; then
    echo "failed locating $ARG_PEER in $WG_CONF_FILE"
    exit 1
fi

if [[ -z "$EXTRACTED_TEXT" ]]; then
    echo "failed enabling $ARG_PEER at $WG_CONF_FILE"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# REMOVE DISABLED FILE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if rm -r "${DISABLED_FILE}"; then
    echo "success: removed disabled file ${DISABLED_FILE}"
else
    echo "failed removal of disabled file ${DISABLED_FILE}"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# UPDATE USER-DEVICE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

FILE_USERDEVICE=${PEER_DIR}/user-device.conf
if [[ -f "${FILE_USERDEVICE}" ]]; then
    # Use sed to replace the value of 'DISABLED=' with the new value
    sed -i "s/^DISABLED=.*/DISABLED=false/" "$FILE_USERDEVICE"
    echo "success: updated ${FILE_USERDEVICE}"
else
    FILE_USERDEVICE=${PEER_DIR}/user-device.json
    FILE_USERDEVICE_TEMP=${PEER_DIR}/temp-user-device.json
    if [[ -f "${FILE_USERDEVICE}" ]]; then
        # Use jq to replace the value of 'disabled' with 'false' and output to a temp file
        if ! jq '.disabled = false' "${FILE_USERDEVICE}" > "${FILE_USERDEVICE_TEMP}"; then
          echo "jq operation failed."
          # Delete the temp file if jq failed
          rm -f "${FILE_USERDEVICE_TEMP}"
          exit 1
        fi
        
        # If jq succeeded, move the temp file to the original file
        mv "${FILE_USERDEVICE_TEMP}" "${FILE_USERDEVICE}"

        echo "success: updated ${FILE_USERDEVICE}"
    fi
fi

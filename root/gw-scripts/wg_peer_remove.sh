#!/bin/bash

ARG_DEVINT=
ARG_PEER=""
ARG_USER_ID=

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function usage {
    echo "Usage: $0 -D <DEVINT> -p <PEER> [PARAMS]"
    echo "  parameters:"
    echo "   -h    help"
    echo "   -D    device interface"
    echo "   -p    peer ID"
    echo "   -U    user id"
}

while getopts "hp:D:U:" opt; do
  case $opt in
    D) # device interface
        ARG_DEVINT=${OPTARG}
        ;;
    p) # peer name/identifier
        ARG_PEER=${OPTARG}
        ;;
    U) # user id
        ARG_USER_ID=${OPTARG}
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

# Function to check if user-device.json contains the userId
contains_userId() {
    local file="$1"
    jq --exit-status ".userId == \"$ARG_USER_ID\"" "$file" > /dev/null 2>&1
}

PEER_ARRAY=()

# Check if ARG_PEER is empty string
if [[ -z "$ARG_PEER" ]]; then
    if [[ -n "$ARG_USER_ID" ]]; then

        # Export the function so it can be used by find's exec
        export -f contains_userId

        # Search for user-device.json files and check for the userId                                                                                                                                       
        while IFS= read -r -d '' file; do                                                                                                                                                                  
            dir=$(dirname "$file")                                                                                                                                                                         
            if contains_userId "$file"; then                                                                                                                                                
                #echo "found directory: $directory"                                                                                                                                                        
                PEER_ARRAY+=("$dir") # Add directory to array                                                                                                                                              
            fi                                                                                                                                                                                             
        done < <(find ${SERVER_DIR}/peer_* -type f -name "user-device.json" -print0)

    fi
else
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

    PEER_ARRAY=("$PEER_DIR")
fi

# If no directories were found
if [ ${#PEER_ARRAY[@]} -eq 0 ]; then
    echo "Parameter -p (PEER) or -U (USERID) is required. Use -h for help."
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# REMOVE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

for dir in "${PEER_ARRAY[@]}"; do
    peerid=$(basename "$dir")

    # remove peer
    if rm -r "${dir}"; then
        echo "success: removed directory ${dir}"
    fi

    # Use sed to delete the block of text between the markers
    sed -i "/# BEGIN $peerid/,/# END $peerid/d" $WG_CONF_FILE
    # Use sed to delete the block of text including the trailing newline
    # does not work
    #sed -i "/# BEGIN $ARG_PEER/,/# END $ARG_PEER/{/# END $ARG_PEER/!d; /# END $ARG_PEER/d; N;}" $WG_CONF_FILE
    
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
done

## remove peer
#if rm -r "${PEER_DIR}"; then
#    echo "success: removed directory ${PEER_DIR}"
#fi
#
## Use sed to delete the block of text between the markers
#sed -i "/# BEGIN $ARG_PEER/,/# END $ARG_PEER/d" $WG_CONF_FILE
## Use sed to delete the block of text including the trailing newline
## does not work
##sed -i "/# BEGIN $ARG_PEER/,/# END $ARG_PEER/{/# END $ARG_PEER/!d; /# END $ARG_PEER/d; N;}" $WG_CONF_FILE
#
## Check if the operation was successful
#if [ $? -eq 0 ]; then
#    echo "success: server config block updated at $WG_CONF_FILE"
#fi
#
## Use sed to collapse multiple empty lines into a single empty line
#sed -i '/^$/N;/\n$/D' $WG_CONF_FILE
#
## Check if the operation was successful
#if [ $? -eq 0 ]; then
#    echo "success: multiple empty lines replaced in $WG_CONF_FILE"
#fi

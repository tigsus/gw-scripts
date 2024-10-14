#!/bin/bash

# Define a function to get and validate the dir name of the file script                                                                                                                                    
get_dirname() {                                                                                                                                                                                            
  # Get the file name of the current script from the BASH_SOURCE variable                                                                                                                                  
  filename="${BASH_SOURCE[0]}"                                                                                                                                                                             
                                                                                                                                                                                                           
  # Get the directory name of the file script using the dirname command                                                                                                                                    
  dirname=$(dirname "$filename")                                                                                                                                                                           
                                                                                                                                                                                                           
  # Check if the directory name is empty, "", or "."                                                                                                                                                       
  if [ -z "$dirname" ] || [ "$dirname" == "." ]; then                                                                                                                                                      
    # Make the directory name equal "./"                                                                                                                                                                   
    dirname="./"                                                                                                                                                                                           
  fi                                                                                                                                                                                                       
                                                                                                                                                                                                           
  # Print the directory name                                                                                                                                                                               
  echo "The directory name of the file script is: $dirname"                                                                                                                                                
                                                                                                                                                                                                           
  # Validate the directory is valid using the -d option                                                                                                                                                    
  if ! [ -d "$dirname" ]; then                                                                                                                                                                               
    # Print an error message and exit with code 1                                                                                                                                                          
    echo "The directory is not valid." >&2                                                                                                                                                                 
    exit 1                                                                                                                                                                                                 
  fi                                                                                                                                                                                                       
                                                                                                                                                                                                           
  # Assign the directory name to a variable BASH_DIRNAME                                                                                                                                                   
  BASH_DIRNAME="$dirname"                                                                                                                                                                                  
}                                                                                                                                                                                                          
                                                                                                                                                                                                           
get_dirname

ARG_DEVINT=wg0

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function usage {
    echo "Usage: $0  -D <DEVINT> [PARAMS]"
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
    echo "Parameter -D (DEVINT) is required. Use -h for help."
    exit 1
fi

WG_CONF_FILE=/config/wg_confs/${ARG_DEVINT}.conf
if [[ -f "${WG_CONF_FILE}" ]]; then
    echo "server file already found for device interface ${ARG_DEVINT} at ${WG_CONF_FILE}"
    exit 1
fi

SERVER_DIR="/config/server_${ARG_DEVINT}"
if [[ -d "${SERVER_DIR}" ]]; then
    echo "server directory already created for device interface ${ARG_DEVINT} at ${SERVER_DIR}"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: CREATE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

${BASH_DIRNAME}/wg_server_create.sh -D ${ARG_DEVINT}

# Success?
if [ $? -ne 0 ]; then
    echo "failed wg_server_create.sh"
    exit 1
fi

if [[ ! -d "${SERVER_DIR}" ]]; then
    echo "failed to locate server directory at ${SERVER_DIR}"
    exit 1
fi

echo "success: wg_server_create.sh"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: PEERS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Define an array with PEERS
my_peers=("TEST1" "TEST2" "TEST3" "TEST4" "TEST5")

for peerid in "${my_peers[@]}"; do
    ${BASH_DIRNAME}/wg_peer_new.sh -D ${ARG_DEVINT} -p ${peerid} -U "bob@example.com"

    # Success?
    if [ $? -ne 0 ]; then
        echo "failed: wg_peer_new.sh (peer_${peerid}"
        exit 1
    fi
    
    PEER_DIR=${SERVER_DIR}/peer_${peerid}
    if [[ ! -d "${PEER_DIR}" ]]; then
        echo "failed: wg_peer_new.sh (peer_${peerid}; no peer directory at ${PEER_DIR}"
        exit 1
    fi

    # Use jq to check the value of 'disabled'
    FILE_USERDEVICE=${SERVER_DIR}/peer_${peerid}/user-device.json
    if [[ ! -f "${FILE_USERDEVICE}" ]]; then
        echo "failed: wg_peer_new.sh (peer_${peerid}; no user device file at ${FILE_USERDEVICE}"
        exit 1        
    fi
    if jq -e '.userId != "bob@example.com"' "${FILE_USERDEVICE}" > /dev/null; then
        echo "failed: wg_peer_new.sh (peer_${peerid}; invalid userId at ${FILE_USERDEVICE}"
        exit 1
    fi
    
    echo "success: wg_peer_new.sh (peer_${peerid}"
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: DOWN-UP
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

${BASH_DIRNAME}/wg_down.sh

# Success?
if [ $? -ne 0 ]; then
    echo "failed wg_down.sh"
    exit 1
fi

${BASH_DIRNAME}/wg_up.sh

# Success?
if [ $? -ne 0 ]; then
    echo "failed wg_up.sh"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: DISABLE PEERS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

for peerid in "${my_peers[@]}"; do
    ${BASH_DIRNAME}/wg_peer_disable.sh -D ${ARG_DEVINT} -p ${peerid}

    # Success?
    if [ $? -ne 0 ]; then
        echo "failed wg_peer_disable.sh"
        exit 1
    fi
    
    FILE_DISABLED=${SERVER_DIR}/peer_${peerid}/disabled.conf
    if [[ ! -f "${FILE_DISABLED}" ]]; then
        echo "failed: wg_peer_disable.sh (peer_${peerid}); disabled file not found at ${FILE_DISABLED}"
        exit 1
    fi
    
    # Use jq to check the value of 'disabled'
    FILE_USERDEVICE=${SERVER_DIR}/peer_${peerid}/user-device.json
    if jq -e '.disabled == false' "${FILE_USERDEVICE}" > /dev/null; then
      echo "failed: wg_peer_disable.sh (peer_${peerid}); the 'disabled' property should be true"
      exit 1
    fi
    
    echo "success: wg_peer_disable.sh (peer_${peerid})"
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: HOT-RELOAD
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

${BASH_DIRNAME}/wg_reload.sh -D ${ARG_DEVINT}

# Success?
if [ $? -ne 0 ]; then
    echo "failed wg_reload.sh"
    exit 1
fi

echo "success: ${BASH_DIRNAME}/wg_reload.sh -D ${ARG_DEVINT}"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: ENABLE PEERS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

for peerid in "${my_peers[@]}"; do
    ${BASH_DIRNAME}/wg_peer_enable.sh -D ${ARG_DEVINT} -p ${peerid}

    # Success?
    if [ $? -ne 0 ]; then
        echo "failed wg_peer_enable.sh"
        exit 1
    fi
    
    FILE_DISABLED=${SERVER_DIR}/peer_${peerid}/disabled.conf
    if [[ -f "${FILE_DISABLED}" ]]; then
        echo "failed: wg_peer_enable.sh (peer_${peerid}); disabled file found at ${FILE_DISABLED}"
        exit 1
    fi

    # Use jq to check the value of 'disabled'
    FILE_USERDEVICE=${SERVER_DIR}/peer_${peerid}/user-device.json
    if jq -e '.disabled == true' "${FILE_USERDEVICE}" > /dev/null; then
      echo "failed: wg_peer_enable.sh (peer_${peerid}); the 'disabled' property should be false"
      exit 1
    fi
    
    echo "success: wg_peer_enable.sh (peer_${peerid})"
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: HOT-RELOAD
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

${BASH_DIRNAME}/wg_reload.sh -D ${ARG_DEVINT}

# Success?
if [ $? -ne 0 ]; then
    echo "failed wg_reload.sh"
    exit 1
fi

echo "success: ${BASH_DIRNAME}/wg_reload.sh -D ${ARG_DEVINT}"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: PEER REMOVES
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

${BASH_DIRNAME}/wg_peer_remove.sh -D ${ARG_DEVINT} -p TEST1

# Success?
if [ $? -ne 0 ]; then
    echo "failed wg_peer_remove.sh -D ${ARG_DEVINT} -p TEST1"
    exit 1
fi

DIR_REMOVE=${SERVER_DIR}/peer_TEST1
if [[ -d "${DIR_REMOVE}" ]]; then
    echo "failed removing directory for peer_TEST1"
    exit 1
fi

echo "success: wg_peer_remove.sh -D ${ARG_DEVINT} -p TEST1"

${BASH_DIRNAME}/wg_peer_remove.sh -D ${ARG_DEVINT} -U "bob@example.com"

# Success?
if [ $? -ne 0 ]; then
    echo "failed wg_peer_remove.sh -D ${ARG_DEVINT} -U \"bob@example.com\""
    exit 1
fi

my_peers=("TEST2" "TEST3" "TEST4" "TEST5")

for peerid in "${my_peers[@]}"; do

    # Success?
    if [ $? -ne 0 ]; then
        echo "failed wg_peer_enable.sh"
        exit 1
    fi

    DIR_REMOVE=${SERVER_DIR}/peer_${peerid}
    if [[ -d "${DIR_REMOVE}" ]]; then
        echo "failed removing directory for peer_${peerid}"
        exit 1
    fi
done

echo "success: wg_peer_remove.sh -D ${ARG_DEVINT} -U \"bob@example.com\""

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: SERVER DESTROY
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

${BASH_DIRNAME}/wg_server_destroy.sh -D ${ARG_DEVINT}

# Success?
if [ $? -ne 0 ]; then
    echo "failed wg_server_destroy.sh"
    exit 1
fi

echo "success: ${BASH_DIRNAME}/wg_server_destroy.sh -D ${ARG_DEVINT}"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS: DOWN
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

${BASH_DIRNAME}/wg_down.sh

# Success?
if [ $? -ne 0 ]; then
    echo "failed wg_down.sh"
    exit 1
fi

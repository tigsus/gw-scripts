#!/bin/bash

# Input file
INPUT_FILE="globals.env"

function convert_env_to_json {                          
    # Check if the input file exists                      
    if [[ ! -f "$INPUT_FILE" ]]; then                           
        echo "Error: $INPUT_FILE not found!" >&2                      
        exit 1                                                        
    fi                                                        
                                                        
    # Start the JSON object                               
    echo "{"                                                    
                                                                      
    # Read the .env file line by line                                 
    first=true                                                
    while IFS='=' read -r key value; do                 
        # Skip empty lines and lines that start with a #  
        if [[ -n "$key" && "$key" != \#* ]]; then                                
            # Add a comma before each new entry except the first                 
            if [[ $first == true ]]; then                             
                first=false                                   
            else                                       
                echo ","                                  
            fi                                                                   
                                                                                 
            # Check for GWContainerWGServerPort and convert to integer
            if [[ "$key" == "GWContainerWGServerPort" ]]; then
                echo "  \"$key\": $value"              
            else                                          
                # Output the key-value pair in JSON format                       
                echo "  \"$key\": \"$value\""                                    
            fi                                          
        fi                                              
    done < "$INPUT_FILE"                               
                                                       
    # End the JSON object                                                        
    echo                                                                         
    echo "}"                                            
                                                               
    exit 0                                                     
}

function initialize_using_defaults {
    # Check if the input file exists
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "Error: $INPUT_FILE not found!" >&2
        exit 1
    fi

    # Load the environment variables from the file
    source "$INPUT_FILE"

    # Check if GWContainerWGDevice is set and not empty
    if [[ -z "${GWContainerWGDevice}" ]]; then
        echo "Error: GWContainerWGDevice is not set or empty in $INPUT_FILE!" >&2
        exit 1
    fi

    # Check for existence of the server device
    DEVICE_PATH="/config/server_${GWContainerWGDevice}"
    if [[ -e "$DEVICE_PATH" ]]; then
        echo "Server device exists at $DEVICE_PATH."
        exit 0
    fi

    # Initialize SERVERURL
    SERVERURL=${SERVERURL:-${GWContainerWGServerUrl:-myserver.example.com}}
    if [[ -z "${SERVERURL}" ]]; then
        echo "Error: SERVERURL is not set or empty!" >&2
        exit 1
    else
        PARAMS="-U ${SERVERURL}"
    fi

    # Initialize SERVERPORT
    SERVERPORT=${SERVERPORT:-${GWContainerWGServerPort:-51820}}
    if [[ -z "${SERVERPORT}" ]]; then
        echo "Error: SERVERPORT is not set or empty!" >&2
        exit 1
    else
        PARAMS="${PARAMS} -P ${SERVERPORT}"
    fi

    # Initialize INTERNAL_SUBNET
    INTERNAL_SUBNET=${INTERNAL_SUBNET:-${GWContainerWGSubnet:-10.13.13.0}}
    if [[ -z "${INTERNAL_SUBNET}" ]]; then
        echo "Error: INTERNAL_SUBNET is not set or empty!" >&2
        exit 1
    else
        PARAMS="${PARAMS} -S ${INTERNAL_SUBNET}"
    fi

    # Initialize PEERDNS
    if [[ -n "${PEERDNS:-${GWContainerWGPeerDNS}}" ]]; then
        PEERDNS=${PEERDNS:-${GWContainerWGPeerDNS}}
        PARAMS="${PARAMS} -N ${PEERDNS}"
    fi

    # Initialize ALLOWEDIPS
    if [[ -n "${ALLOWEDIPS:-${GWContainerWGAllowedIPs}}" ]]; then
        ALLOWEDIPS=${ALLOWEDIPS:-${GWContainerWGAllowedIPs}}
        PARAMS="${PARAMS} -A ${ALLOWEDIPS}"
    fi

    # Initialize PERSISTANTKEEPALIVES
    if [[ -n "${PERSISTANTKEEPALIVES:-${GWContainerWGPersistKeepAlive}}" ]]; then
        PERSISTANTKEEPALIVES=true
        PARAMS="${PARAMS} -K true"
    fi

    # Create WireGuard server
    echo "Creating WireGuard server with parameters: -D ${GWContainerWGDevice} ${PARAMS}"
    /gw-scripts/wg_server_create.sh -D "${GWContainerWGDevice}" ${PARAMS}
    if [[ $? -eq 0 ]]; then
        echo "WireGuard server created successfully."
        exit 0
    else
        echo "Error: Failed to create WireGuard server!" >&2
        exit 1
    fi
}
                                                                                         
function usage {                                                                         
    echo "Usage: $0 [PARAMS]"                                                            
    echo "  parameters:"                                                                 
    echo "   -h    help"                                                                 
    echo "   -j    convert globals.env to json"                          
    echo "   -i    initialize using defaults"               
}                                                                                
                                                                                 
while getopts "hji" opt; do                                           
  case $opt in                                                                           
    j) # convert globals.env to json                                     
        convert_env_to_json                               
        ;;                                                                       
    i) # initialize using defaults                                               
        initialize_using_defaults                             
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

#!/bin/bash

# Input file
INPUT_FILE="/gw-scripts/globals.env"

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
            # Lowercase "GW" prefix for the JSON property name
            json_key=$(echo "$key" | sed 's/^GW/gw/')

            # Handle specific cases for data types
            case "$key" in
                "GWExternalServerPort" | "GWHostWGPort" | "GWHostWebPort" | "GWContainerWGPort" | "GWContainerWGPersistKeepAlive")
                    # Ensure the value is a valid non-negative integer
                    if [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -ge 0 ]]; then
                        echo "  \"$json_key\": $value"
                    else
                        echo "  \"$json_key\": 0"  # Default to 0 if value is invalid, empty, or negative
                    fi
                    ;;
                "GWContainerWGPeerDNS" | "GWContainerWGAllowedIPs")
                    # Convert comma-separated values into JSON array
                    if [[ -z "$value" ]]; then
                        echo "  \"$json_key\": []"
                    else
                        echo "  \"$json_key\": [$(echo "$value" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')]"
                    fi
                    ;;
                "GWServerMode" | "GWUseCoreDNS")
                    # Boolean fields
                    if [[ "$value" == "true" || "$value" == "1" ]]; then
                        echo "  \"$json_key\": true"
                    else
                        echo "  \"$json_key\": false"
                    fi
                    ;;
                *)
                    # Collapse malformed quotes like """" to empty string
                    if [[ "$value" =~ ^\"{2,}$ ]]; then
                        echo "  \"$json_key\": \"\""
                    else
                        echo "  \"$json_key\": \"$value\""
                    fi
                    ;;
            esac
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


    # Check if the device interface (-D) is specified and if settings.env exists
    if [[ -n "$ARG_DEVINT" ]]; then
        SERVER_DIR="/config/server_${ARG_DEVINT}"

        # Load the server-specific settings from settings.env if it exists
        if [[ -f "$SERVER_DIR/settings.env" ]]; then
            echo "**** [INFO] Loading device-specific settings from $SERVER_DIR/settings.env ****"
            source "$SERVER_DIR/settings.env"
        else
            echo "**** [INFO] No device-specific settings found for $ARG_DEVINT. Using global settings. ****"
        fi
    fi

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
    SERVERURL=${SERVERURL:-${GWExternalServerUrl:-myserver.example.com}}
    if [[ -z "${SERVERURL}" ]]; then
        echo "Error: SERVERURL is not set or empty!" >&2
        exit 1
    else
        PARAMS="-U ${SERVERURL}"
    fi

    # Initialize SERVERPORT
    SERVERPORT=${SERVERPORT:-${GWExternalServerPort:-51820}}
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

    # Initialize PERSISTENTKEEPALIVE, normalizing its value.
    PERSISTENTKEEPALIVE="${PERSISTENTKEEPALIVE:-${GWContainerWGPersistKeepAlive:-}}"
    
    if [[ -n "${PERSISTENTKEEPALIVE}" ]]; then
        PARAMS="${PARAMS} -K ${PERSISTENTKEEPALIVE}"
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
    echo "   -D    specify device interface for server-specific settings"
}

# CLI Options Parsing
while getopts "hjiD:" opt; do
  case $opt in
    j) # convert globals.env to json
        convert_env_to_json
        ;;
    i) # initialize using defaults
        initialize_using_defaults
        ;;
    D) # device interface specified for settings.env override
        ARG_DEVINT="${OPTARG}"
        initialize_using_defaults
        ;;
    h | *) # display help
        usage
        exit 0
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        usage
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        usage
        exit 1
        ;;
  esac
done

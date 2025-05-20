#!/bin/bash

ARG_DEVINT=
ARG_FROMDIR=
ARG_FROMDEVINT=

# user device usage
ARG_USERMODE=true

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function usage {
    echo "Usage: $0 -D <DEVINT> -F <FROMDIR> [PARAMS]"
    echo "  parameters:"
    echo "   -h    help"
    echo "   -D    device interface"
    echo "   -F    from directory"
    echo "   -u    user mode (default=true)"
    echo "   -V    from device interface (default=auto-detect)"
}

while getopts "hD:F:V:u:" opt; do
  case $opt in
    D) # device interface
        ARG_DEVINT=${OPTARG}
        ;;
    F) # from dir
        ARG_FROMDIR=${OPTARG}
        ;;
    V) # from dir device interface
        ARG_FROMDEVINT=${OPTARG}
        ;;
    u) # user-mode
        ARG_USERMODE="${OPTARG,,}"
        if [[ "${ARG_USERMODE}" != "false" ]]; then
            ARG_USERMODE=true
        fi
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
# ARG_FROMDIR CHECKS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Check if ARG_FROMDIR is empty string
if [[ -z "${ARG_FROMDIR}" ]]; then
    echo "Parameter -F (FROMDIR) is required. Use -h for help."
    exit 1
fi

if [[ ! -d "${ARG_FROMDIR}" ]]; then
    echo "from directory not found at ${ARG_FROMDIR}"
    exit 1
fi

if [[ ! -d "${ARG_FROMDIR}/server" ]]; then
    echo "from directory server not found at ${ARG_FROMDIR}/server"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ARG_FROMDEVINT CHECKS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

FROM_WG_CONF_FILE=

# If ARG_FROMDEVINT is NOT empty then use this value.
if [[ -n "${ARG_FROMDEVINT}" ]]; then
    FROM_WG_CONF_FILE=${ARG_FROMDIR}/wg_confs/${ARG_FROMDEVINT}.conf    
else
    # Directory exists and is readable, loop through its contents
    for file in "${ARG_FROMDIR}"/wg_confs/*; do
        # Check if the file is a regular file and is readable
        if [ -f "$file" ] && [ -r "$file" ]; then
            # File is a regular file and is readable, print its name and exit the loop
            echo "Found the first wg_conf from file $file"
            FROM_WG_CONF_FILE=$file
            echo "Attempting from device interface extraction"          
            # Remove the directory part of the path using parameter expansion
            file="${file##*/}"
            # Remove the extension part of the file name using parameter expansion
            ARG_FROMDEVINT="${file%.*}"
            if [[ -n "${ARG_FROMDEVINT}" ]]; then
                echo "auto-detect of parameter -V (FROMDEVINT) has succeded; now set to ${ARG_FROMDEVINT}"
            else
                echo "auto-detect failed for arameter -V (FROMDEVINT) using from directory ${ARG_FROMDIR}"
                exit 1        
            fi
            break
        fi
    done
fi

if [[ ! -f "${FROM_WG_CONF_FILE}" ]]; then
    echo "server file not found for from device interface ${ARG_FROMDEVINT} at ${FROM_WG_CONF_FILE}"
    exit 1
else
    echo "discovered from wg_conf file for from device interface ${ARG_FROMDEVINT} at ${FROM_WG_CONF_FILE}"
fi

# Check if ARG_FROMDEVINT is empty string
if [[ -z "${ARG_FROMDEVINT}" ]]; then
    echo "Parameter -V (FROMDEVINT) could not be detected from -F <FROMDIR>. Use -h for help."
    exit 1
fi

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
# LOAD FROM .donoteditthisfile
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

FROM_DONOTEDITTHISFILE=${ARG_FROMDIR}/.donoteditthisfile
if [[ ! -f "${FROM_DONOTEDITTHISFILE}" ]]; then
    echo "failed to located from file hidden enviro vars at ${FROM_DONOTEDITTHISFILE}"
    exit 1
fi

# load into local vars
. ${FROM_DONOTEDITTHISFILE}

if [[ -z "${ORIG_SERVERURL}" ]]; then
    echo "from ORIG_SERVERURL is empty"
    exit 1
fi
if [[ -z "${ORIG_SERVERPORT}" ]]; then
    echo "from ORIG_SERVERPORT is empty"
    exit 1
fi
if [[ -z "${ORIG_PEERDNS}" ]]; then
    echo "from ORIG_PEERDNS is empty"
    exit 1
fi
if [[ -z "${ORIG_INTERFACE}" ]]; then
    echo "from ORIG_INTERFACE is empty"
    exit 1
fi
if [[ -z "${ORIG_ALLOWEDIPS}" ]]; then
    echo "from ORIG_ALLOWEDIPS is empty"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CREATE SERVER
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

mkdir -p "${SERVER_DIR}"
echo "success: creation of server dir for interface ${ARG_DEVINT} at ${SERVER_DIR}"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CREATE SETTINGS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

cat <<DUDE > ${SERVER_DIR}/settings.env
ORIG_DEVINT="$ARG_DEVINT"
ORIG_SERVERURL="${ORIG_SERVERURL}"
ORIG_SERVERPORT="${ORIG_SERVERPORT}"
ORIG_PEERDNS="${ORIG_PEERDNS}"
ORIG_INTERNAL_SUBNET="${ORIG_INTERFACE}.0"
ORIG_INTERFACE="${ORIG_INTERFACE}"
ORIG_ALLOWEDIPS="${ORIG_ALLOWEDIPS}"
ORIG_DOPERSISTENTKEEPALIVE=false
DUDE

echo "success: converted server settings for interface ${ARG_DEVINT} at ${SERVER_DIR}/settings.env"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# COPY SERVER KEYS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

cp "${ARG_FROMDIR}/server/privatekey-server" "${SERVER_DIR}/privatekey-server"
if [ $? -ne 0 ]; then
    echo "failed to copy ${ARG_FROMDIR}/server/privatekey-server to ${SERVER_DIR}/privatekey-server"
    exit 1
fi

cp "${ARG_FROMDIR}/server/publickey-server" "${SERVER_DIR}/publickey-server"
if [ $? -ne 0 ]; then
    echo "failed to copy ${ARG_FROMDIR}/server/publickey-server to ${SERVER_DIR}/publickey-server"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CREATE wg_conf PORTION OF SERVER ONLY
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Use awk to extract the data between "[Interface]" and ("[Peer]" or a single new line) from the source file and place it into the destination file
awk '/^\[Interface\]$/,/^\[Peer\]$|^$/{if ($0 !~ /^\[Peer\]$/ && $0 !~ /^$/) print $0}' "${FROM_WG_CONF_FILE}" > "${WG_CONF_FILE}"
# Check if the awk command was successful
if [ $? -eq 0 ]; then
    # Awk command was successful, print a success message
    echo "successfully extracted the data between [Interface] and [Peer] from ${FROM_WG_CONF_FILE} and placed it into ${WG_CONF_FILE}"
else
    # Awk command failed, print an error message
    echo "failed to extract the data between [Interface] and [Peer] from ${FROM_WG_CONF_FILE} and place it into ${WG_CONF_FILE}"
fi

# add an empty line
echo "" >> ${WG_CONF_FILE}

# Use sed to collapse multiple empty lines into a single empty line
sed -i '/^$/N;/\n$/D' ${WG_CONF_FILE}

# Check if the operation was successful
if [ $? -eq 0 ]; then
    echo "success: multiple empty lines replaced in ${WG_CONF_FILE}"
fi

echo "success: converted from device interface ${FROMDEVINT} to device interface ${ARG_DEVINT}"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CONVERT PEERS
# 1. copy peer directories
# 2. iterate from wg_conf file and look for comment # disabled: peer_PEERID
#    a. if disabled, then inside peer folder create disabled.conf, uncommenting hash elements.
#    b. else write to convert_block.conf
# 3. do a glob on peer_ folder directories
#    a. populate wg_conf, as appropriate
#       a. if not using user file detection, then populate wg_conf
#       b. else if user.json or user.conf exists then check the disabled element
#          a. if disabled then copy convert_block.conf to disabled.conf
#    b. delete convert_block.conf
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# 1. copy peer directories
for dir in "${ARG_FROMDIR}"/*; do
    # Check if the directory name begins with "peer_"
    if [[ "${dir##*/}" == peer_* ]]; then
        # Directory name begins with "peer_", copy it to the destination directory using the -r (recursive) and -f (force) options
        cp -rf "$dir" "${SERVER_DIR}"
        # Check if the copy was successful
        if [ $? -ne 0 ]; then
            # Copy failed, print an error message
            echo "failed to copy $dir into ${SERVER_DIR}"
            exit 1
        fi
    fi
done

# 2. iterate from wg_conf file and look for comment # disabled: peer_PEERID
#    a. if disabled, then inside peer folder create disabled.conf, uncommenting hash elements.
#    b. else write to convert_block.conf
declare -a blocks
# Initialize an empty variable to store the current block of text
block=""
# Initialize a flag to indicate if a block of text has started
started=0
# Loop through the file line by line
while read -r line; do
    # Check if the line begins with "[Peer]"
    if [[ "$line" =~ ^(\[Peer\]|#\s*\[Peer\]) ]]; then
    # Line begins with "[Peer]", check if a block of text has already started
    if [ $started -eq 1 ]; then
        # A block of text has already started, append the current block of text to the array
        blocks+=("$block")
        # Reset the current block of text to empty
        block=""
    fi
        # Set the flag to indicate that a block of text has started
        started=1
    fi
    # Check if a block of text has started
    if [ $started -eq 1 ]; then
        # A block of text has started, append the line to the current block of text
        block+="${line}\n"
    fi
done < "${FROM_WG_CONF_FILE}"

# Check if there is any remaining block of text
if [ -n "$block" ]; then
    # There is a remaining block of text, append it to the array
    blocks+=("$block")
fi
# Print the array elements
for element in "${blocks[@]}"; do
    #echo "$element"
    # Use the ANSI C quoting syntax $'...' to write strings that contain escape sequences.
    # Replace \n with $'\n' in the string using parameter expansion.
    file_converted_block=
    is_disabled=false
    element="${element//\\n/$'\n'}"
    readarray -t array <<< "$element"
    for string in "${array[@]}"; do
        string="${string#"${string%%[![:space:]]*}"}" # Remove leading whitespace
        string="${string%"${string##*[![:space:]]}"}" # Remove trailing whitespace
        if [ -n "${file_converted_block}" ]; then
            if [ -n "${string}" ]; then
                if [[ "${is_disabled}" == "true" ]]; then
                    # Remove the "#" from the beginning of the line using parameter expansion
                    string="${string#\#}"
                    echo ${string} >> ${file_converted_block}
                else
                    echo ${string} >> ${file_converted_block}
                fi
            fi            
        else
            if [[ "$string" == "#"* ]]; then
                # String begins with "#", use awk to extract the first word whose prefix begins with "peer_" after the "#"
                peerid=$(awk -v RS=" " '/^peer_/{print; exit}' <<< "$string")
                # Check if the peerid is not empty
                if [ -n "$peerid" ]; then
                    # peerid is not empty. save the block to a file for conversion later
                    # if the word "disabled" is in the comment, then put the block in disabled.conf
                    if grep -i -q "disabled" <<< "$string"; then
                        # Match! This block is currently disabled.
                        is_disabled=true 
                        file_converted_block=${SERVER_DIR}/${peerid}/disabled.conf
                    else
                        # Match! This block is currently disabled.
                        file_converted_block=${SERVER_DIR}/${peerid}/convert_block.conf
                    fi 
                    #echo "saving converted peer block to $peerid at ${file_converted_block}"
                    echo "# BEGIN ${peerid}" > ${file_converted_block}
                    echo "[Peer]" >> ${file_converted_block}
                fi
            fi
        fi
    done
    
    if [ -n "${file_converted_block}" ]; then
        echo "# END ${peerid}" >> ${file_converted_block}
    fi
done

# 3. do a glob on peer_ folder directories
#    a. populate wg_conf, as appropriate
#       a. if not using user file detection, then populate wg_conf
#       b. else if user.json or user.conf exists then check the disabled element
#          a. if disabled then copy convert_block.conf to disabled.conf
#    b. delete convert_block.conf

# Define the function that checks the user device status from a conf file
check_user_device_status_conf() {
  # Source the environment file to load the variables
  source "$1"
  # Check if the DISABLED variable is set
  if [ -n "$DISABLED" ]; then
    # DISABLED variable is set, use parameter expansion to convert it to lowercase
    disabled="${DISABLED,,}"
    # Check if the lowercase value of the DISABLED variable is "true" or not
    if [ "$disabled" = "true" ]; then
      # Value is "true", return 0 to indicate the user is disabled
      return 0
    else
      # Value is not "true", return 1 to indicate the user is not disabled
      return 1
    fi
  else
    # DISABLED variable is not set, return 2 to indicate the environment file does not contain the DISABLED variable
    return 2
  fi
}

# Define the function that checks the user device status from a json file
check_user_device_status_json() {
  # Use jq to get the value of the disabled property in the json file, ignoring case
  disabled="$(jq -r '.disabled | if type == "string" then ascii_downcase else . end' "$1")"
  # Check if the value is not null
  if [ "$disabled" != "null" ]; then
    # Value is not null, check if the value is "true" or not
    if [ "$disabled" = "true" ]; then
      # Value is "true", return 0 to indicate the user is disabled
      return 0
    else
      # Value is not "true", return 1 to indicate the user is not disabled
      return 1
    fi
  else
    # Value is null, return 2 to indicate the json file does not contain the disabled property
    return 2
  fi
}

# Directory exists and is readable, declare an empty array to store the files paths
declare -a files

# Use find command to search for files that match the pattern "peer_*/convert_block.conf" and append them to the array
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find "${SERVER_DIR}" -type f -name "convert_block.conf" -path "*/peer_*" -print0)

# iterate the files
for file in "${files[@]}"; do

    do_wg_conf=false

    if [[ "${ARG_USERMODE}" != "true" ]]; then
        do_wg_conf=true
    else
        dir="$(dirname "$file")"

        do_disabled=false
        
        if [[ -f "${dir}/user-device.conf" ]]; then
            do_wg_conf=true
            check_user_device_status_conf "${dir}/user-device.conf"
            # Capture the return value of the function
            result=$?
            # Check the result and print a message accordingly
            case $result in
              0) do_disabled=true ;; # echo "The user is disabled" ;;
              1) do_disabled=false ;; # echo "The user is not disabled" ;;
              2) do_disabled= false ;; # echo "The environment file does not contain the DISABLED variable" ;;
            esac
        elif [[ -f "${dir}/user-device.json" ]]; then
            do_wg_conf=true
            check_user_device_status_json "${dir}/user-device.json"
            # Capture the return value of the function
            result=$?
            # Check the result and print a message accordingly
            case $result in
              0) do_disabled=true ;; # echo "The user is disabled" ;;
              1) do_disabled=false ;; # echo "The user is not disabled" ;;
              2) do_disabled= false ;; # echo "The environment file does not contain the DISABLED variable" ;;
            esac
        fi
        
        if [[ "${do_disabled}" == "true" ]]; then
            mv "${file}" "${dir}/disabled.conf"
            continue 
        fi
    fi

    if [[ "${do_wg_conf}" == "true" ]]; then
        # append
        cat ${file} >> ${WG_CONF_FILE}
        # add an empty line
        echo "" >> ${WG_CONF_FILE}
        
        # Check if the operation was successful
        if [ $? -ne 0 ]; then
            echo "failed server config block updated at ${WG_CONF_FILE} from ${file}"
            exit 1
        fi
    fi
    
    # remove the convert blocks file
    rm ${file}
done

# Use sed to collapse multiple empty lines into a single empty line
sed -i '/^$/N;/\n$/D' $WG_CONF_FILE

# Check if the operation was successful
if [ $? -eq 0 ]; then
    echo "success: convert blocks synced to $WG_CONF_FILE"
fi

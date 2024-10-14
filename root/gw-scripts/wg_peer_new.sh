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

ARG_DEVINT=
ARG_PEER=""
ARG_IP=""
ARG_CLIENT_ALLOWED_IPS=""
ARG_DOPERSISTANTKEEPALIVES=

# user device usage
ARG_USERMODE=true
ARG_USERMODE_FORMAT=json
ARG_USER_ID=
ARG_USER_DEVICENAME=
ARG_USER_INTERNALDEVICEID=
ARG_USER_ISDISABLED=false

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function usage {
    echo "Usage: $0 -D <DEVINT> -p <PEER> [PARAMS]"
    echo "  parameters:"
    echo "   -h    help"
    echo "   -D    device interface"
    echo "   -p    peer ID"
    echo "   -i    IP address"
    echo "   -a    allowed client IP addresses or subnets to connect to"
    echo "   -K    persistent keep alive (default=false | true)"
    echo "  user device config"
    echo "   -u    user mode (default=true | false); if false, then no config is expected"
    echo "   -f    format (default=json | conf)"
    echo "   -U    user id"
    echo "   -N    device name (human readable)"
    echo "   -I    internal device id"
    echo "   -d    disabled (default=false | true)"
}

while getopts "hp:i:a:D:K:f:u:U:N:I:d:" opt; do
  case $opt in
    D) # device interface
        ARG_DEVINT=${OPTARG}
        ;;
    p) # peer name/identifier
        ARG_PEER=${OPTARG}
        ;;
    i) # ip address
        ARG_IP=${OPTARG}
        ;;
    a) # allowed ip addresses or subnets
        ARG_CLIENT_ALLOWED_IPS=${OPTARG}
        ;;
    K) # persistant keep alives
        ARG_DOPERSISTANTKEEPALIVES=${OPTARG}
        if [[ "${ARG_DOPERSISTANTKEEPALIVES}" != "true" ]]; then
            ARG_DOPERSISTANTKEEPALIVES=false
        fi
        ;;
    u) # user-mode
        ARG_USERMODE="${OPTARG,,}"
        if [[ "${ARG_USERMODE}" != "false" ]]; then
            ARG_USERMODE=true
        fi
        ;;
    f) # format
        ARG_USERMODE_FORMAT="${OPTARG,,}"
        if [[ "${ARG_USERMODE_FORMAT}" != "conf" ]]; then
            ARG_USERMODE_FORMAT=json
        fi
        ;;
    U) # user id
        ARG_USER_ID=${OPTARG}
        ;;
    N) # user device name (human readable)
        ARG_USER_DEVICENAME="${OPTARG}"
        ;;
    I) # user internal device id
        ARG_USER_INTERNALDEVICEID=${OPTARG}
        ;;
    d) # user is disabled
        ARG_USER_ISDISABLED=${OPTARG,,}
        if [[ "${ARG_USER_ISDISABLED}" != "true" ]]; then
            ARG_USER_ISDISABLED=false
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
if [[ -d "${PEER_DIR}" ]]; then
    echo "${ARG_PEER} already has created directory at ${PEER_DIR}"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# USER-MODE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ "${ARG_USERMODE}" == "true" ]]; then
    if [[ -z "$ARG_USER_ID" ]]; then
        echo "Parameter -U (USERID) is required (eg email) when user-mode is true. Use -h for help."
        exit 1
    fi    
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# HIDDEN ENV LOAD
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

source ${SERVER_DIR}/settings.env

#while IFS== read -r key value; do
#  if [[ ! -z "$key" ]]; then
#    printf -v "$key" %s "$value" && export "$key"
#  fi
#done <${SERVER_DIR}/settings.env
#printenv | grep ORIG_

SERVERURL=${ORIG_SERVERURL}
SERVERPORT=${ORIG_SERVERPORT}
PEERDNS=${ORIG_PEERDNS}
ALLOWEDIPS=${ORIG_ALLOWEDIPS}
INTERFACE=${ORIG_INTERFACE}
INTERNAL_SUBNET=${ORIG_INTERNAL_SUBNET}
DEVINT=${ARG_DEVINT}

if [[ -z "$ARG_DOPERSISTANTKEEPALIVES" ]]; then
    if [[ "$ORIG_DOPERSISTANTKEEPALIVES" = "true" ]]; then
        ARG_DOPERSISTANTKEEPALIVES=true
    else
        ARG_DOPERSISTANTKEEPALIVES=false
    fi
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ARG_IP CHECKS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#INTERFACE=$(echo "$INTERNAL_SUBNET" | awk 'BEGIN{FS=OFS="."} NF--')
if [[ -z "$INTERFACE" ]]; then
    echo "cannot determine INTERFACE from ${INTERNAL_SUBNET} found in ${SERVER_DIR}/settings.env"
    exit 1
fi

if [[ -z "$ARG_IP" ]]; then
    # Discover unused ARG_IP
    # This is a simple discovery. It assumes the "peer*" directories 
    # have been created in order and assigned IPs in order.
    # If a peer has been deleted, then there will be a hole.
    for idx in {2..254}; do
        PROPOSED_IP="${INTERFACE}.${idx}"
        if ! grep -q -R "${PROPOSED_IP}" ${SERVER_DIR}/peer*/*.conf 2>/dev/null && ([[ -z "${ORIG_INTERFACE}" ]] || ! grep -q -R "${ORIG_INTERFACE}.${idx}" ${SERVER_DIR}/peer*/*.conf 2>/dev/null); then
            ARG_IP="${PROPOSED_IP}"
            break
        fi
    done
fi

is_valid_ip() {
    local ip="$1"
    local stat=1

    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
           && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi

    return $stat
}

if ! is_valid_ip "$ARG_IP"; then
    echo "The IP address could not be detected. We tried '$ARG_IP'."
    exit 1
fi


#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ARG_CLIENT_ALLOWED_IPS CHECKS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Check if ARG_ALLOWED_IPS is empty string
if [[ -z "$ARG_CLIENT_ALLOWED_IPS" ]]; then
    # Use the default
    if [[ -z "$ALLOWEDIPS" ]]; then
        echo "Parameter -a (ARG_ALLOWED_IPS) is required. Use -h for help."
        exit 1
    else
        ARG_CLIENT_ALLOWED_IPS=$ALLOWEDIPS
    fi
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# PEERDNS CHECKS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ -z "$PEERDNS" ]] || [[ "$PEERDNS" = "auto" ]]; then
    PEERDNS="${INTERFACE}.1"
    #echo "**** PEERDNS var is either not set or is set to \"auto\", setting peer DNS to ${INTERFACE}.1 to use wireguard docker host's DNS. ****"
#else
#    echo "**** Peer DNS servers will be set to $PEERDNS ****"
fi
 
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# GLOBAL ASSIGNMENTS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# needed for merge in /config/templates/peer.conf
PEER_ID=$ARG_PEER
CLIENT_IP=$ARG_IP
ALLOWEDIPS=$ARG_CLIENT_ALLOWED_IPS

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CREATE DIR
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

mkdir -p "${PEER_DIR}"
echo "created directory for peer ${ARG_PEER} for interface ${ARG_DEVINT} at ${PEER_DIR}"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# PRIVATE-PUBLIC-PRESHARED KEYS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ ! -f "${PEER_DIR}/privatekey-${ARG_PEER}" ]]; then
    umask 077
    wg genkey | tee "${PEER_DIR}/privatekey-${ARG_PEER}" | wg pubkey > "${PEER_DIR}/publickey-${ARG_PEER}"
    wg genpsk > "${PEER_DIR}/presharedkey-${ARG_PEER}"
    echo "created private, public and preshared keys for peer ${ARG_PEER}"
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WRITE CONF
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ -f "${PEER_DIR}/presharedkey-${ARG_PEER}" ]]; then
    # create peer conf with presharedkey
    eval "$(printf %s)
    cat <<DUDE > ${PEER_DIR}/${ARG_PEER}.conf
$(cat /config/templates/peer.conf)
DUDE"
    # add peer info to server conf with presharedkey
    cat <<DUDE >> ${WG_CONF_FILE}
# BEGIN ${ARG_PEER}
[Peer]
PublicKey = $(cat "${PEER_DIR}/publickey-${ARG_PEER}")
PresharedKey = $(cat "${PEER_DIR}/presharedkey-${ARG_PEER}")
DUDE
else
    echo "**** Existing keys with no preshared key found for ${ARG_PEER}, creating confs without preshared key for backwards compatibility ****"
    # create peer conf without presharedkey
    eval "$(printf %s)
    cat <<DUDE > ${PEER_DIR}/${ARG_PEER}.conf
$(sed '/PresharedKey/d' "/config/templates/peer.conf")
DUDE"
    # add peer info to server conf without presharedkey
    cat <<DUDE >> ${WG_CONF_FILE}
# BEGIN ${ARG_PEER}
[Peer]
PublicKey = $(cat "${PEER_DIR}/publickey-${ARG_PEER}")
DUDE
fi
echo "created peer conf at ${PEER_DIR}/${ARG_PEER}.conf"

# add peer's allowedips to server conf
#SERVER_ALLOWEDIPS=SERVER_ALLOWEDIPS_PEER_${i}
#if [[ -n "${!SERVER_ALLOWEDIPS}" ]]; then
#    echo "Adding ${!SERVER_ALLOWEDIPS} to wg0.conf's AllowedIPs for peer ${i}"
#    cat <<DUDE >> ${WG_CONF_FILE}
#AllowedIPs = ${CLIENT_IP}/32,${!SERVER_ALLOWEDIPS}
#DUDE
#else
    cat <<DUDE >> ${WG_CONF_FILE}
AllowedIPs = ${CLIENT_IP}/32
DUDE
#fi

# add PersistentKeepalive if the peer is specified
# otherwise add an empty line
if [[ "${ARG_DOPERSISTANTKEEPALIVES}" = "true" ]]; then
    cat <<DUDE >> ${WG_CONF_FILE}
PersistentKeepalive = 25
# END ${ARG_PEER}

DUDE
else
    cat <<DUDE >> ${WG_CONF_FILE}
# END ${ARG_PEER}

DUDE
fi

echo "update wg_conf for interface ${ARG_DEVINT} at ${WG_CONF_FILE}"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# QR-CODE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ -z "${LOG_CONFS}" ]] || [[ "${LOG_CONFS}" = "true" ]]; then
    echo "PEER ${ARG_PEER} QR code (conf file is saved under ${PEER_DIR}):"
    qrencode -t ansiutf8 < "${PEER_DIR}/${ARG_PEER}.conf"
fi
qrencode -o "${PEER_DIR}/${ARG_PEER}.png" < "${PEER_DIR}/${ARG_PEER}.conf"
echo "created qr-code png at ${PEER_DIR}/${ARG_PEER}.png"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# USER-MODE
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ "${ARG_USERMODE}" == "true" ]]; then
    if [[ "${ARG_USERMODE_FORMAT}" == "json" ]]; then
        cat <<DUDE > "${PEER_DIR}/user-device.json"
{
    "userId": "${ARG_USER_ID}",
    "name": "${ARG_USER_DEVICENAME}",
    "internalId": "${ARG_USER_INTERNALDEVICEID}",
    "disabled": ${ARG_USER_ISDISABLED},
    "wgPeerId": "${ARG_PEER}",
    "clientIP": "${CLIENT_IP}"
}
DUDE
        echo "created user-device.json at ${PEER_DIR}/user-device.json"
    else
        cat <<DUDE > "${PEER_DIR}/user-device.conf"
USERID="${ARG_USER_ID}"
NAME="${ARG_USER_DEVICENAME}"
INTERNALID="${ARG_USER_INTERNALDEVICEID}"
DISABLED=${ARG_USER_ISDISABLED}
WGPEERID="${ARG_PEER}"
CLIENTIP="${CLIENT_IP}"
DUDE
        echo "created user-device.conf at ${PEER_DIR}/user-device.conf"
    fi
    
    ## Use the disabled script to actually disable peer
    if [[ "${ARG_USER_ISDISABLED}" == "true" ]]; then
        ${BASH_DIRNAME}/wg_peer_disable.sh -D ${ARG_DEVINT} -p ${ARG_PEER} 

        # Check if the operation was successful
        if [ $? -ne 0 ]; then
            echo "failed to disable ${ARG_PEER}"
            exit 2
        fi
    fi
fi

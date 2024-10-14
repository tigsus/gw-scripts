#!/bin/bash

ARG_DEVINT=
ARG_SERVERURL=
ARG_SERVERPORT=
ARG_PEERDNS=
ARG_INTERNAL_SUBNET=
ARG_ALLOWEDIPS=
ARG_DOPERSISTANTKEEPALIVES=false

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function usage {
    echo "Usage: $0 -D <DEVINT> [PARAMS]"
    echo "  parameters:"
    echo "   -h    help"
    echo "   -D    device interface"
    echo "   -U    server url"
    echo "   -P    server port"
    echo "   -N    peer dns"
    echo "   -S    internal subnet"
    echo "   -A    allowed-ips"
    echo "   -K    persistant keep alive (default: false)"
}

while getopts "hD:U:P:N:S:A:K:" opt; do
  case $opt in
    D) # device interface
        ARG_DEVINT=${OPTARG}
        ;;
    U) # server url
        ARG_SERVERURL=${OPTARG}
        ;;
    P) # server port
        ARG_SERVERPORT=${OPTARG}
        ;;
    N) # peer dns
        ARG_PEERDNS=${OPTARG}
        ;;
    S) # internal subnet
        ARG_INTERNAL_SUBNET=${OPTARG}
        ;;
    A) # allowed ips
        ARG_ALLOWEDIPS=${OPTARG}
        ;;
    K) # persistant keep alives
        ARG_DOPERSISTANTKEEPALIVES=${OPTARG}
        if [[ "$ARG_DOPERSISTANTKEEPALIVES" != "true" ]]; then
            ARG_DOPERSISTANTKEEPALIVES=false
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
if [[ -f "${WG_CONF_FILE}" ]]; then
    echo "server file already found for device interface ${ARG_DEVINT} at ${WG_CONF_FILE}"
    exit 0
fi

SERVER_DIR="/config/server_${ARG_DEVINT}"
if [[ -d "${SERVER_DIR}" ]]; then
    echo "server directory already created for device interface ${ARG_DEVINT} at ${SERVER_DIR}"
    exit 1
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# VARIABLE CHECKS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if [[ -z "$ARG_SERVERURL" ]]; then
    ARG_SERVERURL=${SERVERURL}
fi
if [[ -z "$ARG_SERVERURL" ]] || [[ "$ARG_SERVERURL" = "auto" ]]; then
    ARG_SERVERURL=$(curl -s icanhazip.com)
    echo "**** SERVERURL var is either not set or is set to \"auto\", setting external IP to auto detected value of $ARG_SERVERURL ****"
else
    echo "**** External server address is set to $ARG_SERVERURL ****"
fi

if [[ -z "$ARG_SERVERPORT" ]]; then
    ARG_SERVERPORT=${SERVERPORT:-51820}
fi
echo "**** External server port is set to ${ARG_SERVERPORT}. Make sure that port is properly forwarded to port 51820 inside this container ****"

if [[ -z "$ARG_INTERNAL_SUBNET" ]]; then
    ARG_INTERNAL_SUBNET=${INTERNAL_SUBNET:-10.13.13.0}
fi
echo "**** Internal subnet is set to $ARG_INTERNAL_SUBNET ****"

INTERFACE=$(echo "$ARG_INTERNAL_SUBNET" | awk 'BEGIN{FS=OFS="."} NF--')

if [[ -z "${ARG_ALLOWEDIPS}" ]]; then
    ARG_ALLOWEDIPS=${ALLOWEDIPS:-0.0.0.0/0, ::/0}
fi
echo "**** AllowedIPs for peers $ARG_ALLOWEDIPS ****"

if [[ -z "$ARG_PEERDNS" ]]; then
    ARG_PEERDNS=${PEERDNS}
fi
if [[ -z "$ARG_PEERDNS" ]] || [[ "$ARG_PEERDNS" = "auto" ]]; then
    ARG_PEERDNS="${INTERFACE}.1"
    echo "**** PEERDNS var is either not set or is set to \"auto\", setting peer DNS to ${ARG_PEERDNS}.1 to use wireguard docker host's DNS. ****"
else
    echo "**** Peer DNS servers will be set to $ARG_PEERDNS ****"
fi

SERVERURL=${ARG_SERVERURL}
SERVERPORT=${ARG_SERVERPORT}
PEERDNS=${ARG_PEERDNS}
INTERNAL_SUBNET=${ARG_INTERNAL_SUBNET}
ALLOWEDIPS=${ARG_ALLOWEDIPS}
DEVINT=$ARG_DEVINT

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CREATE DIR
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

mkdir -p "${SERVER_DIR}"
echo "success: creation of server dir for interface ${ARG_DEVINT} at ${SERVER_DIR}"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ADAPTED FROM init-wireguard-conf/run
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

save_vars () {
    cat <<DUDE > ${SERVER_DIR}/settings.env
ORIG_DEVINT="$ARG_DEVINT"
ORIG_SERVERURL="$SERVERURL"
ORIG_SERVERPORT="$SERVERPORT"
ORIG_PEERDNS="$PEERDNS"
ORIG_INTERNAL_SUBNET="$INTERNAL_SUBNET"
ORIG_INTERFACE="$INTERFACE"
ORIG_ALLOWEDIPS="$ALLOWEDIPS"
ORIG_DOPERSISTANTKEEPALIVES=$ARG_DOPERSISTANTKEEPALIVES
DUDE
}

#switch_on_core_dns () {
    # Switch to true???
    #echo "**** Client mode selected. ****"
    #USE_COREDNS="${USE_COREDNS,,}"
    #printf %s "${USE_COREDNS:-false}" > /run/s6/container_environment/USE_COREDNS
#}
    
save_vars

if [[ ! -f "${SERVER_DIR}/privatekey-server" ]]; then
    umask 077
    wg genkey | tee "${SERVER_DIR}/privatekey-server" | wg pubkey > "${SERVER_DIR}/publickey-server"
fi
eval "$(printf %s)
cat <<DUDE > ${WG_CONF_FILE}
$(cat /config/templates/server.conf)

DUDE"

# Use sed to comment out lines that begin with PostUp or PostDown
sed -i '/^PostUp/s/^/#/' ${WG_CONF_FILE}
sed -i '/^PostDown/s/^/#/' ${WG_CONF_FILE}

# Use sed to uncomment lines that begin with #PostUp or #PostDown
#sed -i '/^#PostUp/s/^#//' "$file_to_modify"
#sed -i '/^#PostDown/s/^#//' "$file_to_modify"

echo "success: creation of wg file for interface ${ARG_DEVINT} at ${WG_CONF_FILE}"


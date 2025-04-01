#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2015-2020 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# https://github.com/WireGuard/wireguard-tools/blob/master/contrib/json/wg-json

ARG_DEVINT=

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
# ARG_DEVINT CHECKS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#exec < <(exec wg show ${ARG_DEVINT} dump)
exec < <(exec wg show all dump)

printf '{'
while read -r -d $'\t' device; do
    if [[ $device == "${ARG_DEVINT}" ]]; then
        if [[ $device != "$last_device" ]]; then
            [[ -z $last_device ]] && printf '\n' || printf '%s,\n' "$end"
            last_device="$device"
            read -r private_key public_key listen_port fwmark
            printf '\t"%s": {' "$device"
            delim=$'\n'
            [[ $private_key == "(none)" ]] || { printf '%s\t\t"privateKey": "%s"' "$delim" "$private_key"; delim=$',\n'; }
            [[ $public_key == "(none)" ]] || { printf '%s\t\t"publicKey": "%s"' "$delim" "$public_key"; delim=$',\n'; }
            [[ $listen_port == "0" ]] || { printf '%s\t\t"listenPort": %u' "$delim" $(( $listen_port )); delim=$',\n'; }
            [[ $fwmark == "off" ]] || { printf '%s\t\t"fwmark": %u' "$delim" $(( $fwmark )); delim=$',\n'; }
            printf '%s\t\t"peers": {' "$delim"; end=$'\n\t\t}\n\t}'
            delim=$'\n'
        else
            read -r public_key preshared_key endpoint allowed_ips latest_handshake transfer_rx transfer_tx persistent_keepalive
            printf '%s\t\t\t"%s": {' "$delim" "$public_key"
            delim=$'\n'
            
            ### Embed the peer's user-device.json file
            filePeerPub=$(grep -rl "$public_key" /config/server_$last_device/peer_*)
            
            if [[ -n "$filePeerPub" ]]; then
                peer_dir=$(dirname "$filePeerPub")
                user_device_json="$peer_dir/user-device.json"
                
                if [[ -f "$user_device_json" ]]; then
                    user_device_data=$(cat "$user_device_json" | tr -d '\n' | tr -d '\r')
                    printf '%s				"userDevice": %s' "$delim" "$user_device_data"
                    delim=$',\n'
                fi
            fi

            [[ $preshared_key == "(none)" ]] || { printf '%s\t\t\t\t"presharedKey": "%s"' "$delim" "$preshared_key"; delim=$',\n'; }
            [[ $endpoint == "(none)" ]] || { printf '%s\t\t\t\t"endpoint": "%s"' "$delim" "$endpoint"; delim=$',\n'; }
            [[ $latest_handshake == "0" ]] || { printf '%s\t\t\t\t"latestHandshake": %u' "$delim" $(( $latest_handshake )); delim=$',\n'; }
            [[ $transfer_rx == "0" ]] || { printf '%s\t\t\t\t"transferRx": %u' "$delim" $(( $transfer_rx )); delim=$',\n'; }
            [[ $transfer_tx == "0" ]] || { printf '%s\t\t\t\t"transferTx": %u' "$delim" $(( $transfer_tx )); delim=$',\n'; }
            [[ $persistent_keepalive == "off" ]] || { printf '%s\t\t\t\t"persistentKeepalive": %u' "$delim" $(( $persistent_keepalive )); delim=$',\n'; }
            printf '%s\t\t\t\t"allowedIps": [' "$delim"
            delim=$'\n'
            if [[ $allowed_ips != "(none)" ]]; then
                old_ifs="$IFS"
                IFS=,
                for ip in $allowed_ips; do
                    printf '%s\t\t\t\t\t"%s"' "$delim" "$ip"
                    delim=$',\n'
                done
                IFS="$old_ifs"
                delim=$'\n'
            fi
            printf '%s\t\t\t\t]' "$delim"
            printf '\n\t\t\t}'
            delim=$',\n'
        fi
    fi
done
printf '%s\n' "$end"
printf '}\n'

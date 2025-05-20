#!/bin/bash

set -e

ARG_DEVINT=""

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

usage() {
    echo "Usage: $0 [-D <DEVICE_INTERFACE>]"
    echo "  Parameters:"
    echo "   -h    Help"
    echo "   -D    WireGuard device interface to inspect (optional; default is all)"
}

while getopts "hD:" opt; do
  case $opt in
    D) ARG_DEVINT=${OPTARG} ;;
    h | *) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
  esac
done

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# VALIDATIONS
#!!!!!!!!!!!!!!!!!!!!!!!!!

if ! command -v wg >/dev/null 2>&1; then
    echo "Error: 'wg' command not found."
    exit 1
fi

if [[ -n "$ARG_DEVINT" ]]; then
    WG_CONF_FILE="/config/wg_confs/${ARG_DEVINT}.conf"
    SERVER_DIR="/config/server_${ARG_DEVINT}"
    if [[ ! -f "$WG_CONF_FILE" || ! -d "$SERVER_DIR" ]]; then
        echo "Error: Device interface $ARG_DEVINT not properly configured."
        exit 1
    fi
fi

# ─── Generate JSON

exec < <(wg show all dump)

printf '{'
first_device=true
delim=$'\n'

while read -r -d $'\t' device; do
    read -r private_key public_key listen_port fwmark

    # Filter if device mismatch
    if [[ -n "$ARG_DEVINT" && "$device" != "$ARG_DEVINT" ]]; then
        # Skip until next device
        while read -r _; do
            [[ "$REPLY" == "$device" ]] && break
        done
        continue
    fi

    [[ "$first_device" == true ]] && first_device=false || printf ',\n'
    printf '\n\t"%s": {' "$device"

    # Device attributes
    inner_delim=$'\n'
    [[ "$private_key" == "(none)" ]] || { printf '%s\t\t"privateKey": "%s"' "$inner_delim" "$private_key"; inner_delim=$',\n'; }
    [[ "$public_key" == "(none)" ]] || { printf '%s\t\t"publicKey": "%s"' "$inner_delim" "$public_key"; inner_delim=$',\n'; }
    [[ "$listen_port" == "0" ]] || { printf '%s\t\t"listenPort": %u' "$inner_delim" "$((listen_port))"; inner_delim=$',\n'; }
    [[ "$fwmark" == "off" ]] || { printf '%s\t\t"fwmark": %u' "$inner_delim" "$((fwmark))"; inner_delim=$',\n'; }

    # Start peers block
    printf '%s\t\t"peers": {' "$inner_delim"
    peer_first=true

    while read -r peer_device peer_public_key preshared_key endpoint allowed_ips latest_handshake transfer_rx transfer_tx persistent_keepalive; do
        if [[ "$peer_device" != "$device" ]]; then
            # Put back the line for the next device
            REPLY="$peer_device"$'\t'"$peer_public_key"$'\t'"$preshared_key"$'\t'"$endpoint"$'\t'"$allowed_ips"$'\t'"$latest_handshake"$'\t'"$transfer_rx"$'\t'"$transfer_tx"$'\t'"$persistent_keepalive"
            break
        fi

        [[ "$peer_first" == true ]] && peer_first=false || printf ',\n'
        printf '\n\t\t\t"%s": {' "$peer_public_key"

        attr_delim=$'\n'

        # Optional user device embed
        filePeerPub=$(grep -rl "$peer_public_key" /config/server_"$device"/peer_* 2>/dev/null || true)
        if [[ -n "$filePeerPub" ]]; then
            peer_dir=$(dirname "$filePeerPub")
            user_device_json="$peer_dir/user-device.json"

            if [[ -f "$user_device_json" ]]; then
                user_device_data=$(tr -d '\n\r' < "$user_device_json")
                printf '%s\t\t\t\t"userDevice": %s' "$attr_delim" "$user_device_data"
                attr_delim=$',\n'
            fi
        fi

        [[ "$preshared_key" == "(none)" ]] || { printf '%s\t\t\t\t"presharedKey": "%s"' "$attr_delim" "$preshared_key"; attr_delim=$',\n'; }
        [[ "$endpoint" == "(none)" ]] || { printf '%s\t\t\t\t"endpoint": "%s"' "$attr_delim" "$endpoint"; attr_delim=$',\n'; }

        if [[ "$latest_handshake" =~ ^[0-9]+$ ]]; then
            printf '%s\t\t\t\t"latestHandshake": %u' "$attr_delim" "$latest_handshake"
            attr_delim=$',\n'
        fi

        if [[ "$transfer_rx" =~ ^[0-9]+$ ]]; then
            printf '%s\t\t\t\t"transferRx": %u' "$attr_delim" "$transfer_rx"
            attr_delim=$',\n'
        fi

        if [[ "$transfer_tx" =~ ^[0-9]+$ ]]; then
            printf '%s\t\t\t\t"transferTx": %u' "$attr_delim" "$transfer_tx"
            attr_delim=$',\n'
        fi

        if [[ "$persistent_keepalive" =~ ^[0-9]+$ ]]; then
            printf '%s\t\t\t\t"persistentKeepalive": %u' "$attr_delim" "$persistent_keepalive"
            attr_delim=$',\n'
        fi

        # Allowed IPs
        printf '%s\t\t\t\t"allowedIps": [' "$attr_delim"
        ip_delim=$'\n'

        if [[ "$allowed_ips" != "(none)" && -n "$allowed_ips" ]]; then
            old_ifs="$IFS"
            IFS=,
            read -ra ip_array <<< "$allowed_ips"
            for i in "${!ip_array[@]}"; do
                printf '%s\t\t\t\t\t"%s"' "$ip_delim" "${ip_array[$i]}"
                if [[ $i -lt $((${#ip_array[@]} - 1)) ]]; then
                    printf ','
                fi
                ip_delim=$'\n'
            done
            IFS="$old_ifs"
        fi

        printf '%s\t\t\t\t]' "$ip_delim"
        printf '\n\t\t\t}'
    done

    printf '\n\t\t}' # End peers block
    printf '\n\t}'   # End device block
done

printf '\n}\n'

#!/bin/bash

set -euo pipefail
trap 'echo "❌ Test failed at line $LINENO" >&2; exit 1' ERR

BASH_DIRNAME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARG_DEVINT="wg0"
ARG_CLEAN=false

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Functions
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]
}

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CLI
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

usage() {
    echo "Usage: $0  -D <DEVINT> [OPTIONS]"
    echo
    echo "Options:"
    echo "  -D <DEVINT>   WireGuard device interface (default: wg0)"
    echo "  -c            Clean environment before running tests"
    echo "  -h            Help"
}

while getopts "hD:c" opt; do
    case $opt in
        D) ARG_DEVINT=${OPTARG} ;;
        c) ARG_CLEAN=true ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

print_success() { echo "✅ $*"; }
print_error() { echo "❌ $*" >&2; exit 1; }

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# PRE-CHECK
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

WG_CONF_FILE="/config/wg_confs/${ARG_DEVINT}.conf"
SERVER_DIR="/config/server_${ARG_DEVINT}"

if [[ "$ARG_CLEAN" == "true" ]]; then
    echo "🧹 Cleaning environment for device: $ARG_DEVINT ..."

    # Properly bring down any running WireGuard interface
    if [[ -f "$WG_CONF_FILE" || -d "$SERVER_DIR" ]]; then
        "${BASH_DIRNAME}/wg_down.sh" || true
        "${BASH_DIRNAME}/wg_server_destroy.sh" -D "${ARG_DEVINT}" || true
    fi

    echo "Environment cleaned: $ARG_DEVINT"
fi

if [[ -f "$WG_CONF_FILE" ]]; then
    print_error "WireGuard config $WG_CONF_FILE already exists. Please clean environment."
fi
if [[ -d "$SERVER_DIR" ]]; then
    print_error "Server directory $SERVER_DIR already exists. Please clean environment."
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# TESTS
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# ─── TEST: Server Create
"${BASH_DIRNAME}/wg_server_create.sh" -D "${ARG_DEVINT}" -K 30
[[ -d "$SERVER_DIR" ]] || print_error "Server directory $SERVER_DIR not created."
print_success "Server created: $SERVER_DIR"

# ─── TEST: Add Peers
my_peers=("TEST1" "TEST2" "TEST3" "TEST4" "TEST5")
ARG_PERSISTENT_KEEPALIVE="30" 

for peerid in "${my_peers[@]}"; do
    "${BASH_DIRNAME}/wg_peer_new.sh" -D "${ARG_DEVINT}" -p "$peerid" -U "bob@example.com" -K "${ARG_PERSISTENT_KEEPALIVE}"
    
    PEER_DIR="${SERVER_DIR}/peer_${peerid}"
    [[ -d "$PEER_DIR" ]] || print_error "Peer directory missing: $PEER_DIR"
    
    # Validate PersistentKeepalive inside SERVER CONF
    if grep -q "# BEGIN peer_${peerid}" "${WG_CONF_FILE}"; then
        # Only if the section was added successfully
        if is_positive_integer "$ARG_PERSISTENT_KEEPALIVE"; then
            if ! sed -n "/# BEGIN peer_${peerid}/,/# END peer_${peerid}/p" "${WG_CONF_FILE}" | grep -q "PersistentKeepalive ="; then
                print_error "PersistentKeepalive missing for peer_${peerid} in server config!"
            fi
        fi
    else
        print_error "Peer block not found for peer_${peerid} in server config!"
    fi
    
    # Validate User device
    FILE_USERDEVICE="$PEER_DIR/user-device.json"
    [[ -f "$FILE_USERDEVICE" ]] || print_error "User device JSON missing: $FILE_USERDEVICE"
    
    if jq -e '.userId != "bob@example.com"' "$FILE_USERDEVICE" > /dev/null; then
        print_error "Invalid userId in $FILE_USERDEVICE"
    fi
    
    print_success "Peer added: peer_${peerid}"
done

# ─── TEST: Bring Down and Up
"${BASH_DIRNAME}/wg_down.sh"
print_success "WireGuard downed"

"${BASH_DIRNAME}/wg_up.sh"
print_success "WireGuard up"

# ─── TEST: Disable Peers
for peerid in "${my_peers[@]}"; do
    "${BASH_DIRNAME}/wg_peer_disable.sh" -D "${ARG_DEVINT}" -p "$peerid"
    
    FILE_DISABLED="${SERVER_DIR}/peer_${peerid}/disabled.conf"
    [[ -f "$FILE_DISABLED" ]] || print_error "Disabled file missing for peer_${peerid}"

    FILE_USERDEVICE="${SERVER_DIR}/peer_${peerid}/user-device.json"
    if jq -e '.disabled == false' "$FILE_USERDEVICE" > /dev/null; then
        print_error "Peer ${peerid} should be disabled but is not."
    fi

    print_success "Peer disabled: peer_${peerid}"
done

# ─── TEST: Hot Reload
"${BASH_DIRNAME}/wg_reload.sh" -D "${ARG_DEVINT}"
print_success "WireGuard reloaded"

# ─── TEST: Enable Peers
for peerid in "${my_peers[@]}"; do
    "${BASH_DIRNAME}/wg_peer_enable.sh" -D "${ARG_DEVINT}" -p "$peerid"
    
    FILE_DISABLED="${SERVER_DIR}/peer_${peerid}/disabled.conf"
    [[ ! -f "$FILE_DISABLED" ]] || print_error "Disabled file should be removed for peer_${peerid}"

    FILE_USERDEVICE="${SERVER_DIR}/peer_${peerid}/user-device.json"
    if jq -e '.disabled == true' "$FILE_USERDEVICE" > /dev/null; then
        print_error "Peer ${peerid} should be enabled but is not."
    fi

    print_success "Peer enabled: peer_${peerid}"
done

# ─── TEST: Hot Reload Again
"${BASH_DIRNAME}/wg_reload.sh" -D "${ARG_DEVINT}"
print_success "WireGuard reloaded after enabling peers"

# ─── TEST: Remove One Peer
"${BASH_DIRNAME}/wg_peer_remove.sh" -D "${ARG_DEVINT}" -p "TEST1"

DIR_REMOVE="${SERVER_DIR}/peer_TEST1"
[[ ! -d "$DIR_REMOVE" ]] || print_error "Failed removing directory for peer_TEST1"
print_success "Peer removed: peer_TEST1"

# ─── TEST: Remove Remaining Peers by UserID
"${BASH_DIRNAME}/wg_peer_remove.sh" -D "${ARG_DEVINT}" -U "bob@example.com"

for peerid in "TEST2" "TEST3" "TEST4" "TEST5"; do
    DIR_REMOVE="${SERVER_DIR}/peer_${peerid}"
    [[ ! -d "$DIR_REMOVE" ]] || print_error "Failed removing directory for peer_${peerid}"
    print_success "Peer removed: peer_${peerid}"
done

# ─── TEST: Server Destroy
"${BASH_DIRNAME}/wg_server_destroy.sh" -D "${ARG_DEVINT}"
print_success "Server destroyed: ${ARG_DEVINT}"

# ─── TEST: Bring Down WireGuard
"${BASH_DIRNAME}/wg_down.sh"
print_success "WireGuard finally down"

# ─── DONE
echo ""
echo "*** All unit tests passed for device interface ${ARG_DEVINT} ***"
exit 0

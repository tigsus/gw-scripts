#!/bin/bash

/etc/s6-overlay/s6-rc.d/svc-wireguard/finish

# Check if the operation was successful
if [ $? -eq 0 ]; then
    echo "success: wireguard has stopped"
else
    echo "failed to remove wireguard"
    exit 1
fi

#!/bin/bash

/etc/s6-overlay/s6-rc.d/svc-wireguard/run

# Check if the operation was successful
if [ $? -eq 0 ]; then
    echo "success: wireguard is running"
else
    echo "failed to run wireguard"
    exit 1
fi


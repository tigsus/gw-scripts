#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found. Exiting."
  exit 1
fi

container_name=${GWContainerName}

# Check if the container is already running
is_running=$(docker container inspect -f '{{.State.Status}}' $container_name 2>/dev/null)

if [ "$is_running" != "running" ]; then
  echo "Starting Docker Compose for ${container_name}..."
  docker compose --env-file .env -f dcompose.yml -p wg up -d || { echo "Failed to start Docker Compose"; exit 1; }
else
  echo "${container_name} is already running."
fi

# Network settings from environment variables
wg_net=${GWContainerWGSubnet}
wg_mask=${GWContainerWGMask}
wg_subnet=${GWContainerWGSubnetMask}
wg_via_gw=${GWDockerHostNetGW}

# Check if the route exists and add if not
if ! ip route | grep -q "${wg_subnet}"; then
  echo "Adding route to ${wg_subnet} via ${wg_via_gw}..."
  sudo route add -net ${wg_net} netmask ${wg_mask} gw ${wg_via_gw} || { echo "Failed to add route"; exit 1; }
else
  echo "Route to ${wg_subnet} already exists."
fi

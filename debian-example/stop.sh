#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found. Exiting."
  exit 1
fi

container_name=${GWContainerName}

# Check if the container is running
is_running=$(docker container inspect -f '{{.State.Status}}' $container_name 2>/dev/null)

if [ "$is_running" = "running" ]; then
  echo "Stopping Docker container ${container_name}..."
  docker compose --env-file .env -f dcompose.yml -p wg down -v || { echo "Failed to stop Docker Compose"; exit 1; }
  echo "Stopped Docker container ${container_name}"
else
  echo "Container ${container_name} is not running."
fi

# Network settings from environment variables
wg_net=${GWContainerWGSubnet}
wg_mask=${GWContainerWGMask}
wg_subnet=${GWContainerWGSubnetMask}
wg_via_gw=${GWDockerHostNetGW}

# Check if the route exists and remove it
if ip route | grep -q "${wg_subnet}"; then
  echo "Deleting route to ${wg_subnet} via ${wg_via_gw}..."
  sudo route del -net ${wg_net} netmask ${wg_mask} gw ${wg_via_gw} || { echo "Failed to delete route"; exit 1; }
else
  echo "No route to ${wg_subnet} found."
fi

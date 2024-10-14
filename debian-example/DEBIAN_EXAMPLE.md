# gw-scripts: Debian Example

This setup demonstrates how to create a WireGuard server that allows remote peers to connect and receive static IP addresses. These static IP addresses will be discoverable within the corporate network infrastructure and pingable from internal servers. This is essential for internal monitoring and logging systems.

The configuration provided enables routing between the host network, a Docker container network, and the WireGuard network. It includes static network creation and a system service (`wg101.service`) to manage routing and service lifecycle on startup and shutdown of the host.

## Overview of Components

- **start.sh / stop.sh**: These scripts are used to start and stop the WireGuard services while applying the appropriate routing.
- **dcompose.yml**: The Docker Compose file responsible for setting up the WireGuard container and its network.
- **wg101.service**: A system service that ensures routing and WireGuard services are correctly handled during system startup/shutdown.

## Setup Directory

Assuming the setup is located in `/opt/wg101`, this directory will hold the required files:

- `.env`: Environment variables used for network and container configuration.
- `start.sh`: Starts the WireGuard service and sets up routing.
- `stop.sh`: Stops the WireGuard service and tears down routing.
- `dcompose.yml`: Docker Compose configuration for the WireGuard container.

### .env File Example

The following environment variables need to be set in the `.env` file:

```bash
GWHostIP=10.10.10.10/24                    # Host's static IP address
GWDockerHostNetName=wgNet101               # Name of the Docker network for the host-container connection
GWDockerHostNetGW=172.24.101.1             # Gateway of the Docker network
GWDockerHostNetGWSubnet=172.24.101.0/24    # Subnet of the Docker network
GWDockerHostContainerIP=172.24.101.2        # IP of the WireGuard container service
GWContainerName=wg101                      # Container name
GWContainerWGGW=192.168.55.1               # WireGuard gateway IP within the container
GWContainerWGSubnet=192.168.55.0           # WireGuard subnet
GWContainerWGMask=255.255.255.0            # WireGuard network mask
GWContainerWGSubnetMask=192.168.55.0/24    # WireGuard subnet with mask
```

## Prerequisites

- **Make the directory**: Create the directory where the configuration and scripts will reside:

  ```bash
  sudo mkdir -p /opt/wg101
  ```

  Alternatively, you can clone the repository and copy the example configuration to `/opt/wg101`:

  ```bash
  git clone https://github.com/tigsus/gw-scripts.git
  sudo cp -r gw-scripts/debian-example /opt/wg101
  ```

- **Apply the correct permissions**: Make sure to apply the correct ownership and permissions to the directory:

  ```bash
  sudo chown -R root:root /opt/wg101
  sudo chmod -R 755 /opt/wg101
  ```

- **Docker**: Ensure Docker is installed on the system. Follow the [Docker installation guide](https://docs.docker.com/get-docker/) if needed.

- **Static IP**: The host machine should be assigned a static IP (e.g., `GWHostIP=10.10.10.10`). Reference the provided `optional/etc-network-interfaces` for guidance on configuring static IPs.

- **Enable Proxy ARP**: Ensure `proxy_arp` is enabled to allow routing across networks.

  ```bash
  # Check if proxy_arp is enabled
  sudo sysctl -a | grep net.ipv4.conf.all.proxy_arp

  # Enable proxy_arp if not already enabled
  sudo sysctl -w net.ipv4.conf.all.proxy_arp=1 >> /etc/sysctl.conf

  # Verify the setting
  sudo sysctl -a | grep net.ipv4.conf.all.proxy_arp
  ```

### Create a Static Docker Network

Before running the `start.sh` script, create a static Docker network as referenced in `dcompose.yml`. This network should not be deleted.

```bash
# Create the host-to-container network
sudo docker network create --subnet 172.24.101.0/24 --gateway=172.24.101.1 wgNet101
```

### Test the Setup

Ensure both the `start.sh` and `stop.sh` scripts run without errors.

```bash
# Start the WireGuard service and apply routing
./start.sh

# Stop the WireGuard service and remove routing
./stop.sh
```

## Systemd Service Setup

To automate starting and stopping the WireGuard service during system boot and shutdown, create a `wg101.service` file for `systemd`.

### Create the `wg101.service` File

```bash
sudo vim /etc/systemd/system/wg101.service
```

Add the following content:

```ini
[Unit]
Description=WireGuard Docker Compose Service for Network 101 with Routable Client
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/wg101
ExecStart=/opt/wg101/start.sh
ExecStop=/opt/wg101/stop.sh
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

### Enable and Manage the Service

To enable the service to run at startup:

```bash
sudo systemctl enable wg101.service
```

Start the service:

```bash
sudo service wg101 start
```

Check the status of the service:

```bash
sudo service wg101 status
```

Stop the service:

```bash
sudo service wg101 stop
```

To restart the service:

```bash
sudo service wg101 start
```

This setup will now ensure that your WireGuard service and network routing are properly managed through Docker and `systemd`.

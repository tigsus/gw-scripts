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
GWContainerWGServerUrl=myserver.example.com  # The external DNS/IP of the publicly accessible interface (eg edge router)
GWContainerWGServerPort=51820                # The external port of the publicly accessible interface (eg edge router)
GWContainerWGTimeZone=America/Chicago        # The time-zone to use
GWHostIP=10.10.10.10/24                      # Host's static IP address
GWDockerHostNetName=wgNet101                 # Name of the Docker network for the host-container connection
GWDockerHostNetGW=172.24.101.1               # Gateway of the Docker network
GWDockerHostNetGWSubnet=172.24.101.0/24      # Subnet of the Docker network
GWDockerHostContainerIP=172.24.101.2         # IP of the WireGuard container service
GWContainerName=wg101                        # Container name
GWContainerWGDevice=wg0                      # Wireguard device name inside the container
GWContainerWGGW=192.168.55.1                 # WireGuard gateway IP within the container
GWContainerWGSubnet=192.168.55.0             # WireGuard subnet
GWContainerWGMask=255.255.255.0              # WireGuard network mask
GWContainerWGSubnetMask=192.168.55.0/24      # WireGuard subnet with mask
GWContainerWGPeerDNS=                        # The DNS Server to use
GWContainerWGAllowedIPs=                     # Allowed IP subnets to connect to
GWContainerWGPersistKeepAlive=               # If "true", then persist keep alive is enabled for the server by default
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

- **Persistent Data**: Create a directory to contain persistent configuration data.

  ```bash
  sudo mkdir -p /opt/wg101/data/config
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

#### Testing Notes

On the host, after `start.sh` is run, ensure routes have been created for both the Docker network and the subnet mapping to the host gateway.

```bash
$ ip route
# Docker host network subnet and gateway
172.24.101.0/24 dev br-c49662a2c02e proto kernel scope link src 172.24.101.1
# Route added to the container subnet via the Docker host gateway
192.168.55.0/24 via 172.24.101.1 dev br-c49662a2c02e scope link
```

View the Docker host gateway interface and IP.

```bash
# Find the interface with the IP of 172.24.101.1
15: br-c49662a2c02e: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:93:97:2f:a3 brd ff:ff:ff:ff:ff:ff
    inet 172.24.101.1/24 brd 172.24.101.255 scope global br-c49662a2c02e
    valid_lft forever preferred_lft forever
    inet6 fe80::42:93ff:fe97:2fa3/64 scope link
    valid_lft forever preferred_lft forever
```

If using volume to persistent data, verify a clean file hierarchy.
In the example below `./data/config` on the host volume is mapped to the container's `/config` directory.

```bash
$ sudo tree
.
├── data
│      └── config
│             ├── coredns
│             │         └── Corefile
│             ├── templates
│             │         ├── peer.conf
│             │         └── server.conf
│             └── wg_confs
├── dcompose.yml
├── DEBIAN_EXAMPLE.md
├── optional
│   └── etc-network-interfaces
├── start.sh
├── stop.sh
└── wg101.service
```

View the running container process.

```bash
 docker ps
CONTAINER ID   IMAGE                            COMMAND   CREATED         STATUS         PORTS                                           NAMES
40b3e6f50a42   tigsus/gw-scripts:1.0.20210914   "/init"   4 minutes ago   Up 4 minutes   0.0.0.0:51820->51820/udp, :::51820->51820/udp   wg101
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
sudo service start wg101
```

Check the status of the service:

```bash
sudo service status wg101
```

Stop the service:

```bash
sudo service stop wg101
```

To restart the service:

```bash
sudo service start wg101
```

This setup ensures that your WireGuard service and network routing are properly managed through Docker and `systemd`.

For full assurance, reboot the computer or virtual machine and verify that the IPs, routes, and containers are all running as expected.

## Usage

Follow this [section](../README.md#usage) in the root README, but note that the container name in this example is `wg101`, which differs from the one in the README. To get a shell into the container, run the following:

```bash
docker exec -it wg101 bash
```

The following example creates a new server interface, along with a custom subnet and DNS.

```bash
./wg_server_create.sh -D wg0 -N 8.8.8.8 -S 192.168.55.0
```

Create a peer config tied to a specific user and limiting networks that can be accessed.

```bash
$ ./wg_peer_new.sh -D wg0 -p PEER1 -U "bob@example.com" -N "work laptop" -a "10.11.11.0/24, 10.11.12.0/24"
```

At this point, wireguard is not running. Start the wireguard service.

```bash
./wg_up.sh
```

Verify the server is listening.

```bash
./wg_server_status.sh -D wg0
{
	"wg0": {
		"privateKey": "AFn7x7BGfnjQ3n32ypKrn+H469M8yknH/3NCwrbiJ3s=",
		"publicKey": "8unQCCfGQ8U3U+6x8mzGL9qxCvq+lhpqG66BfqK6fWY=",
		"listenPort": 51820,
		"peers": {
			"4ui5otNlXDyIJjb/g7fbJjeVBZBYgdR1lY9qfV/7BxU=": {
				"presharedKey": "mTWhbxSGAz8TS57uhxB70Yecd3lqMfYwFgpNZ8wt20A=",
				"allowedIps": [
					"192.168.55.2/32"
				]
			}
		}
	}
}
```

View IPs.

```bash
# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host proto kernel_lo 
       valid_lft forever preferred_lft forever
3: wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 qdisc noqueue state UNKNOWN group default qlen 1000
    link/none 
    inet 192.168.55.1/32 scope global wg0
       valid_lft forever preferred_lft forever
20: eth0@if21: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:18:65:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.24.101.2/24 brd 172.24.101.255 scope global eth0
       valid_lft forever preferred_lft forever
```

# gw-scripts

**gw-scripts** is a lightweight set of Bash scripts to help manage WireGuard VPN servers and peers using Docker. It automates setup, management, and configuration of WireGuard, allowing you to define VPN services using a structured `.env` file. It also introduces additional metadata fields that make it easier to associate users or accounts with specific peers — supporting better auditability and user tracking in multi-peer environments.

## Architecture

At its core, `gw-scripts` builds upon the widely-used [linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard) image. This base image is built on Alpine Linux and utilizes the **s6-overlay** for process supervision and container lifecycle management. This architecture ensures lightweight deployment, robust service orchestration, and clean separation of duties between the operating environment and VPN-specific logic.

The `gw-scripts` layer adds a full suite of automation Bash scripts to simplify WireGuard server and peer setup, while remaining tightly aligned with Docker practices. This design allows `gw-scripts` to integrate seamlessly with CLI-based workflows.

---

## Features

- Declarative environment-based configuration
- Simple `up`, `down`, `reload`, and status scripts for server control
- Peer management tools: add, remove, enable, disable
- Docker-first: works seamlessly in isolated containers
- Optional support for CoreDNS and IP routing/firewall customization
- Convert from existing LinuxServer WireGuard setups

---

## Quick Start with Docker

### Option 1: Standalone `docker run`

```bash
docker run -d \
  --name gw-scripts \
  --cap-add NET_ADMIN \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/Chicago \
  -v ./required.env:/gw-scripts/globals.env \
  --restart unless-stopped \
  tigsus/gw-scripts:1.0.20210914-12
````

### Option 2: `docker-compose.yml`

```yaml
services:
  gw-scripts:
    image: tigsus/gw-scripts:1.0.20210914-12
    container_name: ${GWContainerName}
    cap_add:
      - NET_ADMIN
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=${GWContainerWGTimeZone:-America/Chicago}
    volumes:
      - ./required.env:/gw-scripts/globals.env
    ports:
      - "${GWHostWGPort:-51820}:51820/udp"
    sysctls:
      - net.ipv4.ip_forward=1
    restart: unless-stopped
```

Run with:

```bash
docker compose up -d
```

---

## Directory Layout

```bash
.
├── required.env           # Required configuration variables
├── docker-compose.yml     # Optional for compose-based setups
└── gw-scripts/            # Inside container: script directory
```

---

## Required Environment Variables (`required.env`)

These control the server’s behavior, subnet, and IP addressing:

```env
# Core Variables
GWHostSystemCtlServiceName=gw.service
GWExternalServerUrl=your.vpn.example.com
GWExternalServerPort=1820
GWHostIP=10.10.10.10/24
GWHostWGPort=1820
GWDockerHostNetName=wgNet101
GWDockerHostNetGW=172.24.101.1
GWDockerHostNetGWSubnet=172.24.101.0/24
GWDockerHostContainerIP=172.24.101.2
GWContainerName=gw-unit-tests
GWContainerWGTimeZone=America/Chicago
GWContainerWGDevice=wg0
GWContainerWGGW=192.168.55.1
GWContainerWGPort=51820
GWContainerWGSubnet=192.168.55.0
GWContainerWGMask=255.255.255.0
GWContainerWGSubnetMask=192.168.55.0/24
GWContainerWGPeerDNS=
GWContainerWGAllowedIPs=
GWContainerWGPersistKeepAlive=
GWServerMode=true
GWUseCoreDNS=false
GWFWRulesType=routable

# Optional Enhancements
GWHostWebPort=443
GWFWRulesWGToLAN=
GWFWRulesLANToWG=
GWFWHostRulesFile=
GWFWContainerRulesFile=
```

---

## Available Scripts

Run any of these from inside the container (`docker exec -it gw-scripts bash` → `cd /gw-scripts`):

* `wg_up.sh` – Start the WireGuard interface
* `wg_down.sh` – Stop the WireGuard interface
* `wg_reload.sh` – Hot reload configuration
* `wg_server_create.sh` – Create a new device (e.g. `wg0`)
* `wg_server_destroy.sh` – Remove a device and its peers
* `wg_server_status.sh` – Show peer and traffic status
* `wg_peer_new.sh` – Add a peer
* `wg_peer_remove.sh` – Delete a peer
* `wg_peer_disable.sh` / `wg_peer_enable.sh` – Toggle peer state
* `wg_peer_list.sh` – List peers
* `wg_convert_from_linuxserver.sh` – Migrate from `linuxserver/wireguard`
* `wg_unit_tests.sh` – Test scripts and environment setup

---

## Example Usage

```bash
docker exec -it gw-scripts bash
cd /gw-scripts

./wg_server_create.sh -D wg0
./wg_peer_new.sh -D wg0 -p peer1
./wg_up.sh
./wg_server_status.sh -D wg0
```

---

## 🛠 Development

To rebuild the image locally:

```bash
docker build \
  --build-arg BUILD_DATE="$(date +%Y%m%d)" \
  --build-arg VERSION="1.0.20210914-12" \
  -t tigsus/gw-scripts:1.0.20210914-12 .
```

---

## To-Do

These are known issues or areas for improvement in the current codebase:

* ⚠️ **Fix `wg_convert_from_linuxserver.sh`**: This script is currently broken due to recent changes in the internal file or environment handling. Needs review and correction to restore compatibility with legacy `linuxserver/wireguard` setups.
* 🧹 **Simplify CoreDNS logic in `wg_server_create.sh` and `wg_peer_new.sh`**: The current parameter structure and toggles for CoreDNS are more complex than necessary. This is a result of attempting to allow DNS-related configuration without reapplying `linuxserver`-style `svc-coredns` settings, which led to overcompensation. We should be able to purge CoreDNS in those scripts.

---

## License

Licensed under [GPLv3](LICENSE).

---

For bugs, improvements, or contributions, visit [https://github.com/tigsus/gw-scripts](https://github.com/tigsus/gw-scripts).

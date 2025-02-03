# gw-scripts

**gw-scripts** is a collection of bash scripts designed to help you manage and configure WireGuard servers and peers using Docker. WireGuard is a fast, modern, and secure VPN tunnel that runs on Linux, Windows, macOS, Android, iOS, and more. Docker is a platform that allows you to run applications in isolated containers.

This project builds upon [linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard), which provides a Docker image for WireGuard.

You can find the Docker image [here](https://hub.docker.com/r/tigsus/gw-scripts) and the source code on [GitHub](https://github.com/tigsus/gw-scripts).

## Quick-Run

The following will run `gw-scripts` pulling from the image on docker hub.

```bash
$ docker run -d \
    --name gw-scripts \
    --cap-add NET_ADMIN \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ=America/Chicago \
    -e SERVERURL=myserver.example.com \
    -e SERVER_MODE=true \
    -e LOG_CONFS=false \
    --restart unless-stopped \
    tigsus/gw-scripts:1.0.20210914-7
```
> In order to use `wg_globals.sh` (optional in `gw-scripts`) include `globals.env`. In the Debian folder there is a sample `.env` file. To use it, add parameter `-v debian-example/.env:/gw-scripts/globals.env`.

## Features

gw-scripts provides the following scripts to help you set up and manage your WireGuard servers and peers:

- `wg_down.sh`: This script brings down the `wg` server (all device interfaces).
- `wg_up.sh`: This script brings up the `wg` server (all device interfaces).
- `wg_reload.sh`: This script performs a hot reload of a single device interface that won't disrupt active sessions.
- `wg_server_create.sh`: This script creates a new server device interface. Use option `-L` to list existing servers.
    - It makes a directory at `/config/server_DEVINT`.
    - It makes a new server file in `config/wg_confs/DEVINT.conf`.
- `wg_server_destroy.sh`: This script deletes all references to a server by its device interface.
    - It deletes the directory at `/config/server_DEVINT`.
    - It deletes the server file in `config/wg_confs/DEVINT.conf`.
- `wg_server_status.sh`: This script shows a status listing of all peers for a single device interface and includes these outputs:
    - `Address`, `Endpoint`, `Last-Handshake`, `TransferRx` and `TransferTx`
    - It is a tweaked version of `wg-json` found in [wireguard-tools contribs](https://github.com/WireGuard/wireguard-tools/blob/master/contrib/json/wg-json)
- `wg_peer_list.sh`: This script retrieves a listing of peers for a specified device interface (`DEVINT`), with optional filters for `PEERID`, `USERID`, or specific file types (`conf`, `png`, `json`).
    - The script fetches data directly from the server directory (`/config/server_DEVINT/peer_PEERID`) using the specified parameters.
    - Outputs include peer configuration files (`peer_PEERID.conf`), QR codes (`peer_PEERID.png`), or user-device details (`user-device.json`) as JSON objects or binary data.
    - Uses: Helps to manage and retrieve peer-specific configurations, enabling quick access to peer data and metadata.
- `wg_peer_new.sh`: This script creates a new peer (aka client) by DEVINT using a PEERID and optional USERID.
    - It makes a directory under the server folder `/config/server_DEVINT/peer_PEERID`.
    - It updates the entry in `config/wg_confs/DEVINT.conf`.
    - If using USERID, a "user-device.json" file is created inside the peer directory.
- `wg_peer_disable.sh`: This script disables a peer by DEVINT and PEERID.
    - It extracts PEERID info, removing it from `config/wg_confs/DEVINT.conf`.
    - It saves the extracted info as `disabled.conf` under the peer folder.
- `wg_peer_enable.sh`: This script enables a disabled peer by DEVINT and PEERID.
    - It discovers if the peer has a corresponding `disabled.conf` under its folder.
    - It appends `disabled.conf` to the end of `config/wg_confs/DEVINT.conf`.
    - It removes `disabled.conf`.
- `wg_peer_remove.sh`: This script removes a peer (aka client) by DEVINT and PEERID or USERID.
    - It deletes the directory under the server folder `/config/server_DEVINT/peer_PEERID`.
    - It removes the peer info in `config/wg_confs/DEVINT.conf`.
- `wg_convert_from_linuxserver.sh`: This script converts a linuxserver `/config` directory to the `gw-scripts` format.
    - peer directories are moved to under the server_DEVINT directory
    - peer names receive BEGIN/END blocks inside `config/wg_confs/DEVINT.conf`.
- `wg_unit_tests.sh`: Used to verify scripts.

## Roll-Your-Own

To roll-your-own gw-scripts, you need to have Docker and Docker Compose installed on your system. 

1. Clone our repository to your local drive:

```bash
git clone https://github.com/tigsus/gw-scripts.git
cd gw-scripts
```

2. Make your changes to the source.

## Docker Build

Update the Dockerfile with the desired [version](https://hub.docker.com/r/linuxserver/wireguard/tags) of [linuxserver/wireguard](https://hub.docker.com/r/linuxserver/wireguard). For custom-builds, replace our repo information `tigsus/gw-scripts` with your own. 

```bash
docker build --build-arg BUILD_DATE="$(date +%Y%m%d)" --build-arg VERSION="1.0.20210914-7" -t tigsus/gw-scripts:1.0.20210914-7 .
```

## Docker Compose

Build the Docker container, then run the sample docker compose file.

1. Run the Docker Compose command to start the WireGuard server and the gw-scripts container:

```bash
docker compose up -d
```

2. Check the logs to see if everything is working:

```bash
docker compose logs -f
```

## Usage

To use gw-scripts, you need to access the gw-scripts container and run the scripts from there. 
You can do this by using the following command:

```bash
docker exec -it gw-scripts bash
```

This will open a bash shell inside the gw-scripts container.
Next, enter the gw-scripts folder, as follows:

```bash
cd /gw-scripts
```

From there, you can run the scripts as you wish. 
For example, to create a new server device interface named `wg0`, you can run:

```bash
./wg_server_create.sh -D wg0
```

To create a new peer for the `wg0` server with the peer ID `1`, you can run:

```bash
./wg_peer_new.sh -D wg0 -p PEER1
```

To disable the peer with the ID `PEER1` for the `wg0` server, you can run:

```bash
./wg_peer_disable.sh -D wg0 -p PEER1
```

To enable the disabled peer with the ID `PEER1` for the `wg0` server, you can run:

```bash
./wg_peer_enable.sh -D wg0 -p PEER1
```

To remove the peer with the ID `PEER1` for the `wg0` server, you can run:

```bash
./wg_peer_remove.sh -D wg0 -p PEER1
```

To bring up the wireguard server, you can run:

```bash
./wg_up.sh
```

To bring down the entire wireguard server, you can run:

```bash
./wg_down.sh
```

To perform a hot reload of the `wg0` server, you can run:

```bash
./wg_reload.sh -D wg0
```

To view the status of the `wg0` server, including `Address`, `Endpoint`, `Last-Handshake`, `TransferRx` and `TransferTx`, you can run:

```bash
./wg_server_status.sh -D wg0
```

To delete the `wg0` server and all its references, you can run:

```bash
./wg_server_destroy.sh -D wg0
```

To convert from a linuxserver file structure, in Docker mount the directory to convert from (eg `/from-configs`). 
See the comment in docker-compose.yml for a mount example. It is best to run on a clean installation.
Then run the convertor script:

```bash
./wg_convert_from_linuxserver.sh -D wg0 -F "/from-configs"
```

To verify scripts, run the included unit-tester. If it errors, the script exits immediately, 
allowing one to inspect the current state for debugging purposes.

```bash
./wg_unit_tests.sh -D wg0
```

## Breaking Changes

The jump from an existing installation of [linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard) to using gw-scripts is not immediate. 
There are breaking changes. Here are some of them:

- All servers (e.g. `wg0`) are identified as device interfaces (`DEVINT`).
- New servers are created via `wg_server_create.sh`.
- A new server folder gets created in `/config/server_DEVINT`.
    - New peers are added between BEGIN/END delimiters to assure ease of extraction.
- Peers are created **under** the server folder and not at the level of `/config`.
- No auto-creation of peers. Why? Syntax differences and unwanted re-synchronization updates. Initialize with `SERVER_MODE=true` to avoid `USECOREDNS` logic.
    - > Note: This could be added back but in a way that plays nice with gw-scripts.
- We commented out the `iptable` rules in `/defaults/server.conf`.

## Contributing

gw-scripts is an open source project and we welcome contributions from anyone who is interested. If you want to contribute to gw-scripts, please follow these steps:

1. Fork this repository and create a new branch for your feature or bug fix.
2. Make your changes and commit them with a clear and descriptive message.
3. Push your branch to your forked repository and create a pull request to the main repository.
4. Wait for the maintainers to review and merge your pull request.

Please make sure to follow the code style and conventions of the project, and to test your changes before submitting a pull request. You can also check the [issues](https://github.com/tigsus/gw-scripts/issues) page to see if there are any open tasks that you can help with.

## License

gw-scripts is licensed under the [GPL Version 3](LICENSE). See the [LICENSE](LICENSE) file for more details.


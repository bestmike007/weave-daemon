# Weave Daemon running in Docker

## Purpose

+ Build your SDN private network upon any network (https://www.weave.works/products/weave-net/)
+ Expose host to SDN network
+ Route all traffic through SDN network (and you need to setup a public gateway and join the network)
+ Add any container with env `WEAVE_IP` to the SDN network (in some circumstances you cannot run container with --net and --ip option)
+ Run as daemon using docker

## Example Usage

With docker cli:

```bash
docker run -d --name=weave-daemon --net=host --privileged --restart=always \
  -e WEAVE_ROUTER_CMD="--ipalloc-range 192.168.0.0/24 node-01 node-02" \
  -e WEAVE_SUBNET=192.168.0.0/24 \
  -e WEAVE_HOST_IP=192.168.0.100 \
  -e WEAVE_ROUTE_GATEWAY=192.168.0.254 \
  -e WEAVE_NETWORK_NAME=mysdn \
  -v /var/run/docker.sock:/var/run/docker.sock \
  bestmike007/weave-daemon:1.6.0
```

With docker compose:

```yml
version: '2'

services:
  weave-daemon:
    image: bestmike007/weave-daemon
    restart: always
    privileged: true
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WEAVE_ROUTER_CMD=--ipalloc-range 192.168.0.0/24 node-01 node-02
      - WEAVE_SUBNET=192.168.0.0/24
      - WEAVE_HOST_IP=192.168.0.100
      - WEAVE_ROUTE_GATEWAY=192.168.0.254
      - WEAVE_NETWORK_NAME=mysdn
```

Environment `WEAVE_ROUTER_CMD`, `WEAVE_SUBNET`, `WEAVE_ROUTE_GATEWAY` and `WEAVE_HOST_IP` are required to setup your weave network and weave plugin. Others are optional.

If you need to setup the default route gateway for the host and route all traffic through weave network, you simply set the `WEAVE_ROUTE_HOST_GATEWAY` environment variable to the gateway IP, e.g. `WEAVE_ROUTE_HOST_GATEWAY=192.168.0.254`

## Add SDN IP to Container

In some cases you cannot run container with --net and --ip options, e.g. `docker run -d --net=mysdn --ip=192.168.0.100 alpine sh`, you can run weave daemon along with those containers simply set up a `WEAVE_IP` env.

```bash
docker run -d -e WEAVE_IP=192.168.0.100 alpine sh
```

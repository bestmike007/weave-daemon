# Weave Daemon running in Docker

## Purpose

+ Build your SDN private network upon any network (https://www.weave.works/products/weave-net/)
+ Expose host to SDN network
+ Route all traffic through SDN network (and you need to setup a public gateway and join the network)
+ Add any container with env `WEAVE_IP` to the SDN network (in some circumstances you cannot run container with --net and --ip option)
+ Run as daemon using docker

## Example Usage

```yml
version: '2'

services:
  weave-daemon:
    image: weave-daemon
    restart: always
    privileged: true
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WEAVE_ROUTER_CMD=--ipalloc-range 192.168.0.0/24 10.0.0.1 10.0.0.2 10.0.0.3
      - WEAVE_SUBNET=192.168.0.0/24
      - WEAVE_HOST_CIDR=192.168.0.0/24
      - WEAVE_ROUTE_GATEWAY=192.168.0.1
      - WEAVE_NETWORK_NAME=mysdn
```

Environment `WEAVE_ROUTER_CMD` and `WEAVE_SUBNET` is required to setup your weave network and weave plugin. Others are optional.

If you need to setup `WEAVE_HOST_CIDR` or `WEAVE_ROUTE_GATEWAY` you need to run this container in privileged mode and also use host network.

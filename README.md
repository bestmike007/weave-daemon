# Weave Daemon running in Docker

## Purpose

+ Build your SDN private network upon any network (https://www.weave.works/products/weave-net/)
+ Expose host to SDN network
+ Route all traffic through SDN network (you need to setup a NAT gateway and join the weave network)
+ Add any container with env `WEAVE_CIDR` to the SDN network (in some circumstances you need a watch dog to run the weave attach command for you, e.g. you do not want to use weave plugin or weave proxy for compatibilities)
+ Run as daemon using docker

## Example Usage

```yml
version: '2'

services:
  weave-daemon:
    image: bestmike007/weave-daemon:1.9.4
    restart: always
    privileged: true
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WEAVE_ROUTER_CMD=--ipalloc-range 192.168.0.0/24 10.0.0.1 10.0.0.2 10.0.0.3
      - WEAVE_HOST_CIDR=192.168.0.0/24
      - WEAVE_ROUTE_GATEWAY=192.168.0.1
```

```bash
docker run -d --name=weave-daemon --net=host --privileged --restart=always \
  -e WEAVE_ROUTER_CMD="--ipalloc-range 192.168.0.0/24 10.0.0.1 10.0.0.2 10.0.0.3" \
  -e WEAVE_HOST_CIDR=192.168.0.0/24 \
  -e WEAVE_ROUTE_GATEWAY=192.168.0.1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  bestmike007/weave-daemon:1.9.4
```

Environment `WEAVE_ROUTER_CMD` is required to setup your weave network and weave plugin. Others are optional.

If you need to setup `WEAVE_HOST_CIDR` or `WEAVE_ROUTE_GATEWAY` you need to run this container in privileged mode along with host network. If `WEAVE_ROUTE_GATEWAY` (which act as a NAT gateway in the weave network) is set, host default route gateway will be changed to this value so that all traffic will go through the weave network.

## Add SDN IP to Container

In some cases you need to attach weave network to container(s), you can run weave daemon along with those containers and simply set up a `WEAVE_CIDR` env for any containers you need a fixed weave network ip attached.

```bash
docker run -d --restart=always -e WEAVE_CIDR=192.168.0.100/24 alpine sh
```

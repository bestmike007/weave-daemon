#!/bin/sh
trap "exit 1" SIGTERM TERM
trap "echo 'Cleaning up...'; exit 0" SIGHUP SIGINT
export TOP_PID=$$
NETWORK_NAME=${WEAVE_NETWORK_NAME:-custom}

[ -z "$WEAVE_ROUTER_CMD" ] && (
  echo "You must specify WEAVE_ROUTER_CMD env. e.g. --ipalloc-range 192.168.0.0/24 weave-node-0 weave-node-1"
  sleep 60
  kill -s TERM $TOP_PID
)

[ -z "$WEAVE_SUBNET" ] && (
  echo "You must specify WEAVE_SUBNET env. e.g. WEAVE_SUBNET=192.168.0.0/24"
  sleep 60
  kill -s TERM $TOP_PID
)

[ -z "$WEAVE_HOST_IP" ] && (
  echo "You must specify WEAVE_HOST_IP env. e.g. WEAVE_HOST_IP=192.168.0.100"
  sleep 60
  kill -s TERM $TOP_PID
)

[ -z "$WEAVE_ROUTE_GATEWAY" ] && (
  echo "You must specify WEAVE_ROUTE_GATEWAY env. e.g. WEAVE_ROUTE_GATEWAY=192.168.0.1"
  sleep 60
  kill -s TERM $TOP_PID
)

weave setup || exit 1
weave reset
echo "Starting weave router..."
weave launch-router $WEAVE_ROUTER_CMD || (
  echo "Fail to launch router..."
  sleep 60
  kill -s TERM $TOP_PID
)
ip link set weave down
ip link del weave

[ `docker network ls -f name=${NETWORK_NAME} | wc -l` -eq 1 ] && (
  docker network create --subnet=${WEAVE_SUBNET} --aux-address "DefaultGatewayIPv4=${WEAVE_ROUTE_GATEWAY}" \
      --gateway=${WEAVE_HOST_IP} -o com.docker.network.bridge.name=br${NETWORK_NAME}\
      -o com.docker.network.driver.mtu=1410 ${NETWORK_NAME} || (
    echo "Fail to create custom docker network..."
    sleep 60
    kill -s TERM $TOP_PID
  )
) || (
  echo "Warning: docker network ${NETWORK_NAME} already exists."
)
brctl addif br${NETWORK_NAME} vethwe-bridge

iptables -I DOCKER-ISOLATION -i br${NETWORK_NAME} -j RETURN
iptables -I DOCKER-ISOLATION -o br${NETWORK_NAME} -j RETURN
[ ! -z "$WEAVE_ROUTE_HOST_GATEWAY" ] && (
  while [ `ip route | grep -e ^default | wc -l` -gt 0 ]; do ( route delete default ) done
  route add default gw $WEAVE_ROUTE_HOST_GATEWAY
)

EVENT_SINCE=`date +%s`

docker ps --no-trunc -q | while read CID; do (
  CIDR_ENV=`docker inspect -f "{{range .Config.Env}}{{println .}}{{end}}" $CID | grep -e ^WEAVE_IP=`
  [ ! -z "$CIDR_ENV" ] && (
    export $CIDR_ENV
    echo "Setting ip ${WEAVE_IP} for container id ${CID}"
    docker network connect --ip=${WEAVE_IP} ${NETWORK_NAME} ${CID}
  )
) done

docker events --since $EVENT_SINCE -f "event=start" -f "event=create" | while read event; do (
  CID=`echo $event | awk '{print $4}'`
  CIDR_ENV=`docker inspect -f "{{range .Config.Env}}{{println .}}{{end}}" $CID | grep -e ^WEAVE_IP=`
  [ ! -z "$CIDR_ENV" ] && (
    export $CIDR_ENV
    echo "Setting ip ${WEAVE_IP} for container id ${CID}"
    docker network connect --ip=${WEAVE_IP} ${NETWORK_NAME} ${CID}
  )
) done

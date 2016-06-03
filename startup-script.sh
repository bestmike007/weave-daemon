#!/bin/sh
trap "exit 1" SIGTERM TERM
trap "echo 'Cleaning up...'; exit 0" SIGHUP SIGINT
export TOP_PID=$$
NETWORK_NAME=${WEAVE_NETWORK_NAME:-custom}

[ -z "$WEAVE_ROUTER_CMD" ] && (
  echo "You must specify WEAVE_ROUTER_CMD env. e.g. --no-discovery --no-dns --ipalloc-range 192.168.0.0/24 weave-node-0 weave-node-1"
  echo "Note: --no-restart is added by default"
  sleep 60
  kill -s TERM $TOP_PID
)

[ -z "$WEAVE_SUBNET" ] && (
  echo "You must specify WEAVE_SUBNET env. e.g. WEAVE_SUBNET=192.168.0.0/24"
  sleep 60
  kill -s TERM $TOP_PID
)

weave setup || exit 1
weave stop || exit 1
echo "Starting weave router..."
weave launch-router $WEAVE_ROUTER_CMD || (
  echo "Fail to launch router..."
  sleep 60
  kill -s TERM $TOP_PID
)

echo "Starting weave plugin..."
weave launch-plugin || (
  echo "Fail to launch plugin..."
  sleep 60
  kill -s TERM $TOP_PID
)
[ `docker network ls -f name=${NETWORK_NAME} | wc -l` -eq 1 ] && (
  docker network create -d weavemesh --subnet=${WEAVE_SUBNET} ${NETWORK_NAME} || (
    echo "Fail to create custom docker network..."
    sleep 60
    kill -s TERM $TOP_PID
  )
) || (
  echo "Warning: docker network ${NETWORK_NAME} already exists."
)

[ ! -z "$WEAVE_HOST_CIDR" ] && (
  echo "Binding ip $WEAVE_HOST_CIDR to host..."
  weave expose $WEAVE_HOST_CIDR || ip addr change $WEAVE_HOST_CIDR dev weave
  iptables -D FORWARD -i docker0 -o weave -j DROP
  [ ! -z "$WEAVE_ROUTE_GATEWAY" ] && (
    while [ `ip route | grep -e ^default | wc -l` -gt 0 ]; do ( route delete default ) done
    route add default gw $WEAVE_ROUTE_GATEWAY
  )
)

docker events --since "1970-01-01" -f "event=start" -f "event=create" | while read event; do (
  CID=`echo $event | awk '{print $4}'`
  CIDR_ENV=`docker inspect -f "{{range .Config.Env}}{{println .}}{{end}}" $CID | grep -e ^WEAVE_IP=`
  [ ! -z "$CIDR_ENV" ] && (
    export $CIDR_ENV
    echo "Setting ip ${WEAVE_IP} for container id ${CID}"
    docker network connect --ip=${WEAVE_IP} ${NETWORK_NAME} ${CID}
  )
) done

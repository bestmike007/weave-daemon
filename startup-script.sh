#!/bin/sh
export TOP_PID=$$
trap "echo 'Force killed...'; kill -s TERM $TOP_PID; exit 1" SIGTERM TERM
trap "echo 'Cleaning up...'; kill -s TERM $TOP_PID; exit 0" SIGHUP SIGINT INT HUP EXIT SIGQUIT

[ "$1" == "setup" ] && (
  weave setup
  kill -s TERM $TOP_PID
)

echo "Starting weave daemon using docker ${DOCKER_VERSION} and weave ${WEAVE_VERSION}..."
sleep 3

[ -z "$WEAVE_ROUTER_CMD" ] && (
  echo "You must specify WEAVE_ROUTER_CMD env. e.g. --ipalloc-range 192.168.0.0/24 weave-node-0 weave-node-1"
  sleep 60
  kill -s TERM $TOP_PID
)

[ -z "`docker ps -qf ancestor=weaveworks/weave:${WEAVE_VERSION}`" ] && (
  weave reset --force
  echo "Starting weave..."
  weave launch-router $WEAVE_ROUTER_CMD || (
    echo "Fail to launch router..."
    sleep 60
    kill -s TERM $TOP_PID
  )
  weave expose $WEAVE_HOST_CIDR || weave expose
) || (
  echo "NOTICE: weave router has already been started, if it's not started by weave daemon please stop it manually."
)

[ ! -z "$WEAVE_HOST_CIDR" ] && (
  echo "Binding ip $WEAVE_HOST_CIDR to host..."
  [ -z "`ip addr show weave | grep $WEAVE_HOST_CIDR`" ] && (
    weave expose || weave expose
  )
  [ -z "`ip addr show weave | grep $WEAVE_HOST_CIDR`" ] && (
    ip addr change $WEAVE_HOST_CIDR dev weave
  )
  [ -z "`iptables-save | grep 'FORWARD -o weave -j ACCEPT'`" ] && iptables -D FORWARD -o weave -j ACCEPT
  [ -z "`iptables-save | grep 'FORWARD -i weave -j ACCEPT'`" ] && iptables -D FORWARD -i weave -j ACCEPT
  [ -z "`iptables-save | grep 'FORWARD -i docker0 -o weave -j DROP'`" ] && iptables -D FORWARD -i docker0 -o weave -j DROP
  iptables -I FORWARD -o weave -j ACCEPT
  iptables -I FORWARD -i weave -j ACCEPT
  [ -z "`iptables-save | grep 'FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu'`" ] && iptables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
  [ ! -z "$WEAVE_ROUTE_GATEWAY" ] && (
    while [ `ip route | grep -e ^default | wc -l` -gt 0 ]; do ( route delete default ) done
    route add default gw $WEAVE_ROUTE_GATEWAY
  )
)

echo "Binding weave ip for all containers with env WEAVE_CIDR..."

(docker ps --no-trunc -q && docker events --since `date +%s` --format '{{.ID}}' -f "event=start") | while read CID; do (
  CIDR_ENV=`docker inspect -f "{{range .Config.Env}}{{println .}}{{end}}" $CID | grep -e ^WEAVE_CIDR=`
  [ ! -z "$CIDR_ENV" ] && (
    export $CIDR_ENV
    echo "Setting ip ${WEAVE_CIDR} for container id ${CID}"
    weave attach ${WEAVE_CIDR} ${CID} || (
      echo "Retry setting ip ${WEAVE_CIDR} for container id ${CID}"
      sleep 3
      weave attach ${WEAVE_CIDR} ${CID}
    )
  ) &
) done

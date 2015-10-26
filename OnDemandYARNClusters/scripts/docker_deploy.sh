#!/bin/bash -x
# Author: Swapnil Daingade and Sarjeet Singh
# Script executed by Executor (Mesos) to launch a docker container as Mesos Task
# This docker container will function as a Yarn ResourceManager or NodeManager
# We configure storage and network for the docker container as part of this script.

echo "Starting deploying script"

while [ $# -gt 0 ]
do
  case "$1" in
  -TYPE) shift
         containerType=$1;;
  -NAME) shift
         taskName=$1;;  #taskName given by Mesos
  -CLUSTER) shift
         clusterId=$1;; #YARN cluster to which this node belongs, E.g. Red cluster, Blue cluster etc
  -IMAGE) shift
         image=$1;;     #Image to be deployed by docker.
  -ZK_ADDR_EXT) shift
         zkAddrExt=$1;; #Zookeeper address (External)
  -HOST_IP) shift
         hostIp=$1;;
  -SCHEDULER_PORT) shift
         schedulerPort=$1;;
  -RMUI_PORT) shift
         rmuiPort=$1;;
  -MYRIADUI_PORT) shift
         myriaduiPort=$1;;
  -NM_OCTET) shift
         nmOctet=$1;;
  -RM_IP) shift
         rmIp=$1;;
  esac
  shift
done


# Pre container launch actions

if [ "$containerType" = "RM" ]; then
  docker_env=(-e "ZK_ADDR_EXT=$zkAddrExt" -e "HOST_IP=$hostIp" -e "SCHEDULER_PORT=$schedulerPort" -e "FWK_NAME=$clusterId")
else
  docker_env=(-e "RM_IP"=$rmIp)
fi

# TODO Make loop back device to be exposed to container configurable
device="/dev/loop0"
# Create container with storage device attached. Attach container to overlay network corresponding to cluster
#cid=`docker run --cap-add=ALL --device=$device:/dev/sdc -itd --publish-service=$taskName.$clusterId $image`
cid=`docker run --privileged -itd "${docker_env[@]}" -m 5120M --oom-kill-disable --publish-service=${taskName//\./\-}.$clusterId $image`
echo "Created container is $cid"

# Configuring networking
# Inspired from code here https://docs.docker.com/articles/networking/
# Each container has two network interfaces.
# First, eth0 is connected to the overlay network corresponding
#   to the YARN cluster
# Second, eth1 is connected to a bridge corresponding to the YARN cluster
#   This allows the node to access the underlay network but not a node
#   in another YARN cluster.

pid=`docker inspect -f '{{.State.Pid}}' $cid` #
echo "pid for container is $pid"

mkdir -p /var/run/netns
ln -s /proc/$pid/ns/net /var/run/netns/$pid
ip addr show $clusterId

#shorten length of container id
originalCid=$cid
cid=${cid:4:5}

# Each cluster has its own bridge per host to connect to the underlay network
bridgeIP=`ip addr show $clusterId | grep 'inet .* global' | awk '{print $2}' | sed 's/\/16//'`
RM_IP=`ip addr show $clusterId | grep 'inet .* global' | awk '{print $2}' | sed 's/1\/16/2/'`

if [ "$containerType" = "RM" ]; then
  containerIp=`ip addr show $clusterId | grep 'inet .* global' | awk '{print $2}' | sed 's/1\/16/2/'`
else
  containerIp=`ip addr show $clusterId | grep 'inet .* global' | awk '{print $2}' | sed "s/1\/16/${nmOctet}/"` 
fi

# Create a veth pair 
ip link add $clusterId-$cid-0 type veth peer name $clusterId-$cid-1

# Add one end to the bridge
brctl addif $clusterId $clusterId-$cid-0
ip link set $clusterId-$cid-0 up

# Change namespace of the other end of veth pair to that of the container
ip link set $clusterId-$cid-1 netns $pid
# Rename to eth1
ip netns exec $pid ip link set dev $clusterId-$cid-1 name eth1
ip netns exec $pid ip link set eth1 up
ip netns exec $pid ip addr add $containerIp/16 dev eth1
# Set default route via bridge (eth1). Delete existing (eth0)
ip netns exec $pid ip route delete default
ip netns exec $pid ip route add default via $bridgeIP


# Post container launch actions
if [ "$containerType" = "RM" ]; then
  iptables -A DOCKER -d ${RM_IP}/32 ! -i $clusterId -o $clusterId -p tcp -m tcp --dport $schedulerPort -j ACCEPT
  iptables -t nat -A POSTROUTING -s ${RM_IP}/32 -d ${RM_IP}/32 -p tcp -m tcp --dport $schedulerPort -j MASQUERADE
  iptables -t nat -A DOCKER -p tcp -m tcp --dport $schedulerPort -j DNAT --to-destination ${RM_IP}:${schedulerPort}

  #RM UI port
  iptables -A DOCKER -d ${RM_IP}/32 ! -i $clusterId -o $clusterId -p tcp -m tcp --dport 8088 -j ACCEPT
  iptables -t nat -A POSTROUTING -s ${RM_IP}/32 -d ${RM_IP}/32 -p tcp -m tcp --dport 8088 -j MASQUERADE
  iptables -t nat -A DOCKER -p tcp -m tcp --dport $rmuiPort -j DNAT --to-destination ${RM_IP}:8088

  #Myriad UI
  iptables -A DOCKER -d ${RM_IP}/32 ! -i $clusterId -o $clusterId -p tcp -m tcp --dport 8192 -j ACCEPT
  iptables -t nat -A POSTROUTING -s ${RM_IP}/32 -d ${RM_IP}/32 -p tcp -m tcp --dport 8192 -j MASQUERADE
  iptables -t nat -A DOCKER -p tcp -m tcp --dport $myriaduiPort -j DNAT --to-destination ${RM_IP}:8192
fi

# Ideally this should be both for RM and NM
if [ "$containerType" = "NM" ]; then
  while [[ `docker inspect -f '{{.State.Status}}' $originalCid` == "running" ]];
  do
    echo "Container $originalCid is running..."
    sleep 5;
  done
fi


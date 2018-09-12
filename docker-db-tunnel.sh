#!/usr/bin/env bash

GREEN=$(echo -en '\033[00;32m')
YELLOW=$(echo -en '\033[00;33m')
RESTORE=$(echo -en '\033[0m')

test -f .env && source .env

DB_TUNNEL_NETWORK=${DB_TUNNEL_NETWORK:-'db-tunnel-network'}
DB_TUNNEL_CONTAINER_NAME=${DB_TUNNEL_CONTAINER_NAME:-'db-tunnel-sshd'}
DB_TUNNEL_CONTAINER_PORT=${DB_TUNNEL_CONTAINER_PORT:-'22666'}
DB_CONTAINER_NAME_PATTERN=${DB_CONTAINER_NAME_PATTERN:-'mariadb|mysql'}

docker network inspect ${DB_TUNNEL_NETWORK} &> /dev/null
if [ $? -eq 1 ]
then
    echo "Creating db tunnel network: ${GREEN}${DB_TUNNEL_NETWORK}${RESTORE}"
    docker network create ${DB_TUNNEL_NETWORK}
fi

# return true/false or error if not exist
IS_TUNNEL_CONTAINER_RUNNING=$(docker inspect -f "{{.State.Running}}" ${DB_TUNNEL_CONTAINER_NAME} 2> /dev/null)
if [ "$IS_TUNNEL_CONTAINER_RUNNING" == "" ]; then
    echo "Running db tunnel container with name: ${GREEN}${DB_TUNNEL_CONTAINER_NAME}${RESTORE}"
    docker run -d -p ${DB_TUNNEL_CONTAINER_PORT}:22 --restart=always --name ${DB_TUNNEL_CONTAINER_NAME} --network ${DB_TUNNEL_NETWORK} sickp/alpine-sshd
elif [ "$IS_TUNNEL_CONTAINER_RUNNING" == "false" ]; then
    echo "Starting existing db tunnel container with name: ${GREEN}${DB_TUNNEL_CONTAINER_NAME}${RESTORE}"
    docker start ${DB_TUNNEL_CONTAINER_NAME} 1> /dev/null
fi

# @todo consider filter by label (e.g. label=db.network.tunnel, label=database, label=mysql)
docker ps --filter "status=running" --filter "name=${DB_CONTAINER_NAME_PATTERN}" --format "{{.Names}} {{.Networks}}" \
| grep -v ${DB_TUNNEL_NETWORK} \
| cut -d ' ' -f 1 \
| while read container_name ; do
    echo "Connecting ${YELLOW}${container_name}${RESTORE} to ${DB_TUNNEL_NETWORK}";
    docker network connect ${DB_TUNNEL_NETWORK} ${container_name};
  done

#!/bin/bash

# Grant claude access to the host Docker socket
if [ -S /var/run/docker.sock ]; then
  DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
  if ! getent group "$DOCKER_GID" > /dev/null 2>&1; then
    sudo groupadd -g "$DOCKER_GID" dockerhost
  fi
  DOCKER_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1)
  sudo usermod -aG "$DOCKER_GROUP" claude
fi

exec /bin/bash "$@"

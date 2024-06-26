#!/bin/bash

# This script is used to get the docker pull quota for the docker hub account

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

NGINX_VERSION=1.25.3
NGINX_IMAGE="nginx:$NGINX_VERSION"

docker pull docker.io/k8sschool/k8s-toolbox:latest
docker pull "$NGINX_IMAGE"
kind load docker-image "$NGINX_IMAGE"

# From workstation:
# docker save "$NGINX_IMAGE" > "/tmp/nginx.tar"
# IP=$($DIR/../infra/scw/get_ip.sh)
# scp "/tmp/nginx.tar" root@$IP:/tmp
# ssh root@"$IP" "docker load --input /tmp/nginx.tar"

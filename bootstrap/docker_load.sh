#!/bin/bash

# This script is used to get the docker pull quota for the docker hub account

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# TODO TODO!!!

NGINX_VERSION=1.25.3
NGINX_IMAGE="nginx:$NGINX_VERSION"

IMAGES=(
  "$NGINX_IMAGE"
  "k8sschool/kubectl-proxy:1.27.3"
  "curlimages/curl"
    "mongo:3.4.1"
    "ubuntu:24.04"
    "docker.io/bitnami/postgresql:14.5.0-debian-11-r14"
    "docker.io/k8sschool/k8s-toolbox:latest"

)

docker login
for IMAGE in "${IMAGES[@]}"; do
  docker pull "$IMAGE"
done

for IMAGE in "${IMAGES[@]}"; do
  kind load docker-image "$IMAGE"
done


# From workstation:
# docker save "$NGINX_IMAGE" > "/tmp/nginx.tar"
# IP=$($DIR/../infra/scw/get_ip.sh)
# scp "/tmp/nginx.tar" root@$IP:/tmp
# ssh root@"$IP" "docker load --input /tmp/nginx.tar"

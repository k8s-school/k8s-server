#!/bin/bash

# This script is used to get the docker pull quota for the docker hub account

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# TODO TODO!!!

NGINX_VERSION=1.25.3
NGINX_IMAGE="nginx:$NGINX_VERSION"

docker login
docker pull k8sschool/kubectl-proxy:1.27.3
docker pull curlimages/curl
docker pull mongo:3.4.1
docker pull ubuntu:24.04
docker pull "$NGINX_IMAGE"
docker pull docker.io/bitnami/postgresql:14.5.0-debian-11-r14

docker pull docker.io/k8sschool/k8s-toolbox:latest
docker pull "$NGINX_IMAGE"
kind load docker-image "$NGINX_IMAGE"

# From workstation:
# docker save "$NGINX_IMAGE" > "/tmp/nginx.tar"
# IP=$($DIR/../infra/scw/get_ip.sh)
# scp "/tmp/nginx.tar" root@$IP:/tmp
# ssh root@"$IP" "docker load --input /tmp/nginx.tar"

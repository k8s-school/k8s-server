#!/bin/bash

# This script is used to get the docker pull quota for the docker hub account

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Check available disk space (require at least 10GB free)
AVAILABLE_GB=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
MIN_REQUIRED_GB=10

echo "Available disk space: ${AVAILABLE_GB}GB"
if [ "$AVAILABLE_GB" -lt "$MIN_REQUIRED_GB" ]; then
  echo "Error: Insufficient disk space. Available: ${AVAILABLE_GB}GB, Required: ${MIN_REQUIRED_GB}GB"
  exit 1
fi

NGINX_VERSION=1.25.3
NGINX_IMAGE="nginx:$NGINX_VERSION"

IMAGES=(
  "$NGINX_IMAGE"
  "nginx:1.22"
  "nginx:1.23"
  "nginx:alpine"
  "alpine:3.19"
  "alpine:latest"
  "busybox:1.36"
  "k8sschool/kubectl-proxy:1.27.3"
  "k8sschool/kuard-amd64:1"
  "k8sschool/kuard-amd64:blue"
  "k8sschool/kuard-amd64:green"
  "curlimages/curl:8.16.0"
  "mongo:3.4.1"
  "ubuntu:24.04"
  "ubuntu:latest"
  "bitnami/postgresql:latest"
  "golang:1.21-alpine"
  "nginxinc/nginx-unprivileged:1.28.0-alpine3.21-perl"
  # Falco security images
  "docker.io/falcosecurity/falco:0.42.1"
  "docker.io/falcosecurity/falcoctl:0.11.4"
  "docker.io/falcosecurity/falco-driver-loader:0.42.1"
  "docker.io/falcosecurity/falcosidekick:2.32.0"
  "docker.io/falcosecurity/falcosidekick-ui:2.2.0"
  "docker.io/redis/redis-stack:7.2.0-v11"
)

# CKS
IMAGES=(
  "aquasec/kube-bench:v0.14.1"
  "nginx:alpine"
  "busybox:1.36"
  # Falco security images
  "docker.io/falcosecurity/falco:0.42.1"
  "docker.io/falcosecurity/falcoctl:0.11.4"
  "docker.io/falcosecurity/falco-driver-loader:0.42.1"
  "docker.io/falcosecurity/falcosidekick:2.32.0"
  "docker.io/falcosecurity/falcosidekick-ui:2.2.0"
  "docker.io/redis/redis-stack:7.2.0-v11"
)

docker login
for IMAGE in "${IMAGES[@]}"; do
  docker pull "$IMAGE"
done

docker pull "docker.io/k8sschool/k8s-toolbox:latest"
docker pull "docker.io/registry:2"

# Get all kind clusters
CLUSTERS=$(kind get clusters)
if [ -z "$CLUSTERS" ]; then
  echo "No kind clusters found"
  exit 1
fi

echo "Found kind clusters: $CLUSTERS"

# Load images into all kind clusters
for CLUSTER in $CLUSTERS; do
  echo "Loading images into cluster: $CLUSTER"
  for IMAGE in "${IMAGES[@]}"; do
    echo "  Loading $IMAGE into $CLUSTER"
    kind load docker-image "$IMAGE" --name "$CLUSTER"
  done
done


# From workstation:
# docker save "$NGINX_IMAGE" > "/tmp/nginx.tar"
# IP=$($DIR/../infra/scw/get_ip.sh)
# scp "/tmp/nginx.tar" root@$IP:/tmp
# ssh root@"$IP" "docker load --input /tmp/nginx.tar"

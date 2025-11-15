#!/bin/bash

# Create a small nginx proxy instance on Scaleway for cockpit access

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Use nginx-specific environment
. $DIR/env.nginx.sh

if scw instance server list | grep $INSTANCE_NAME; then
  echo "ERROR: Instance $INSTANCE_NAME already exists" >&2
  exit 1
fi

# Get or create IP with k8s tag for the target machine
k8s_ip_id=$(scw instance ip list tags.0="k8s" | grep -w "k8s" | awk '{print $1}' || echo "")
if [ -z "$k8s_ip_id" ]; then
  echo "ERROR: No IP found with tag 'k8s'. Please start the k8s instance first." >&2
  exit 1
fi

k8s_ip=$(scw instance ip get "$k8s_ip_id" | grep Address | awk '{print $2}')
echo "Found k8s instance IP: $k8s_ip"

# Get or create IP for nginx proxy
ip_id=$(scw instance ip list tags.0="$INSTANCE_NAME" | grep -w "$INSTANCE_NAME" | awk '{print $1}' || echo "")
if [ -n "$ip_id" ]; then
  echo "Using existing IP address $ip_id"
else
  ip_id=$(scw instance ip create tags.0="$INSTANCE_NAME" | egrep "^ID" | awk '{print $2}')
  echo "Created new IP address $ip_id"
fi

# Create the instance
scw instance server create zone="fr-par-1" image=$DISTRIBUTION type="$INSTANCE_TYPE" ip="$ip_id" name=$INSTANCE_NAME root-volume=local:$DISK_SIZE

instance_id=$(scw instance server list | grep $INSTANCE_NAME | awk '{print $1}')
ip_address=$(scw instance server wait "$instance_id" | grep PublicIP.Address | awk '{print $2}')

echo "Instance created with IP: $ip_address"

# Wait for SSH access
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$ip_address"
until ssh -o "StrictHostKeyChecking no" root@"$ip_address" true 2> /dev/null; do
  echo "Waiting for sshd on $ip_address..."
  sleep 5
done

# Install nginx proxy with Let's Encrypt
ssh root@"$ip_address" -- "curl -s https://raw.githubusercontent.com/k8s-school/k8s-server/main/bootstrap/ubuntu/nginx-proxy.sh | K8S_IP=$k8s_ip bash"

echo "================================================================"
echo "Nginx proxy setup completed!"
echo "================================================================"
echo "Access cockpit via: https://${ip_address//./-}.nip.io"
echo "Target k8s machine: $k8s_ip:9090"
echo "================================================================"
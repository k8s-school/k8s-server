#!/bin/bash

# Create an Azure Red Hat OpenShift (ARO) cluster.
#
# Prerequisites: run ./prereqs.sh first (az CLI install, login, resource
# provider registration, vCPU quota check).

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. $DIR/env.sh

# Resource group
az group create -n "$RESOURCE_GROUP" -l "$LOCATION"

# VNet + master/worker subnets (ARO requires a pre-existing VNet)
az network vnet create -g "$RESOURCE_GROUP" -n "$VNET_NAME" \
  --address-prefixes "$VNET_CIDR"
az network vnet subnet create -g "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" \
  -n "$MASTER_SUBNET" --address-prefixes "$MASTER_CIDR"
az network vnet subnet create -g "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" \
  -n "$WORKER_SUBNET" --address-prefixes "$WORKER_CIDR"

# Reuse the Red Hat pull secret if present at the repo root (gitignored).
# Without it the cluster still works, minus Red Hat marketplace content.
PULL_SECRET_FILE="$DIR/../pull-secret.txt"
pull_secret_arg=()
if [ -f "$PULL_SECRET_FILE" ]; then
  pull_secret_arg=(--pull-secret "@$PULL_SECRET_FILE")
else
  echo "WARNING: $PULL_SECRET_FILE not found, creating cluster without pull secret"
fi

# Pre-create the cluster's AAD application/service principal ourselves,
# as two separate az calls. az aro create's built-in creation calls
# "create application" immediately followed by "add password" on the new
# object, which routinely fails with a Microsoft Graph eventual-consistency
# error ("Resource ... does not exist"); splitting the calls gives Graph
# time to catch up. Reused on re-runs.
CLUSTER_APP_NAME="$CLUSTER_NAME-cluster-sp"
client_id=$(az ad app list --display-name "$CLUSTER_APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$client_id" ]; then
  client_id=$(az ad app create --display-name "$CLUSTER_APP_NAME" --query appId -o tsv)
  sleep 10
fi

# Disable xtrace around the secret so it never hits logs.
set +x
client_secret=$(az ad app credential reset --id "$client_id" --query password -o tsv)

echo "+ az aro create -g $RESOURCE_GROUP -n $CLUSTER_NAME --vnet $VNET_NAME --master-subnet $MASTER_SUBNET --worker-subnet $WORKER_SUBNET --master-vm-size $MASTER_VM_SIZE --worker-vm-size $WORKER_VM_SIZE --worker-count $WORKER_COUNT --client-id $client_id --client-secret *** ${pull_secret_arg[*]:-}"
az aro create -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" \
  --vnet "$VNET_NAME" \
  --master-subnet "$MASTER_SUBNET" \
  --worker-subnet "$WORKER_SUBNET" \
  --master-vm-size "$MASTER_VM_SIZE" \
  --worker-vm-size "$WORKER_VM_SIZE" \
  --worker-count "$WORKER_COUNT" \
  --client-id "$client_id" \
  --client-secret "$client_secret" \
  "${pull_secret_arg[@]}"
set -x

# Show how to connect
console_url=$(az aro show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" \
  --query consoleProfile.url -o tsv)

echo
echo "Cluster '$CLUSTER_NAME' ready."
echo "Console: $console_url"
echo "Credentials: az aro list-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME"
echo
echo "Remember to tear it down when done: $DIR/teardown.sh"

#!/bin/bash

# Create an Azure Red Hat OpenShift (ARO) cluster.
#
# Prerequisites (run once per subscription):
#   az login
#   az provider register --namespace Microsoft.RedHatOpenShift --wait
#   az provider register --namespace Microsoft.Compute --wait
#   az provider register --namespace Microsoft.Storage --wait
#   az provider register --namespace Microsoft.Authorization --wait

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

az aro create -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" \
  --vnet "$VNET_NAME" \
  --master-subnet "$MASTER_SUBNET" \
  --worker-subnet "$WORKER_SUBNET" \
  "${pull_secret_arg[@]}"

# Show how to connect
console_url=$(az aro show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" \
  --query consoleProfile.url -o tsv)

echo
echo "Cluster '$CLUSTER_NAME' ready."
echo "Console: $console_url"
echo "Credentials: az aro list-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME"
echo
echo "Remember to tear it down when done: $DIR/teardown.sh"

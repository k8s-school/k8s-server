#!/bin/bash

# Tear down the ARO cluster by deleting its whole resource group.
# This removes the cluster, the VNet, subnets and everything else in the group,
# so billing stops. Deleting the group is the fastest, most complete teardown.

set -euo pipefail

usage () {
  echo "Usage: $0 [-y] [-h]"
  echo "Delete the ARO resource group (cluster + network)"
  echo "  -h: Display this help message"
  echo "  -y: Skip confirmation prompt"
  exit 1
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. $DIR/env.sh

assume_yes=false
while getopts yh opt; do
  case $opt in
    y) assume_yes=true ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done

if ! az group show -n "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "WARN: Resource group $RESOURCE_GROUP does not exist, nothing to do"
  exit 0
fi

if [ "$assume_yes" = false ]; then
  read -r -p "Delete resource group '$RESOURCE_GROUP' and ALL its resources? [y/N] " answer
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted"; exit 1 ;;
  esac
fi

echo "Deleting resource group $RESOURCE_GROUP..."
az group delete -n "$RESOURCE_GROUP" --yes
echo "Done."

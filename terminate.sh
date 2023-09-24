#!/bin/bash

# Terminate the 'openshift' instance on Scaleway


set -euxo pipefail

INSTANCE_NAME="k8s"
instance_id=$(scw instance server list | grep "$INSTANCE_NAME" | awk '{print $1}')

if [ -n "$instance_id" ]; then
  echo "Terminate $instance_id"
  scw instance server terminate "$instance_id"
else
  echo "Instance openshift not created"
  exit 1
fi

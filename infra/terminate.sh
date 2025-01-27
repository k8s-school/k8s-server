#!/bin/bash

# Terminate the 'openshift' instance on Scaleway

set -euo pipefail

usage () {
  echo "Usage: $0 [-d] [-h]"
  echo "Terminate the kubernetes instance on Scaleway"
  echo "  -h: Display this help message"
  echo "  -d: Delete the IP address associated with the instance"
  exit 1
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. $DIR/env.sh

delete_ip=false
while getopts dh opt; do
  case $opt in
    d)
      delete_ip=true
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

instance_id=$(scw instance server list | grep "$INSTANCE_NAME" | awk '{print $1}' || echo "")

if [ -n "$instance_id" ]; then
  echo "Terminate $instance_id"
  scw instance server terminate "$instance_id"
else
  echo "WARN: Instance $INSTANCE_NAME does not exist"
fi

if [ "$delete_ip" = true ]; then
  ip_id=$(scw instance ip list tags.0="$INSTANCE_NAME" | grep "$INSTANCE_NAME" |   awk '{print $1}')
  echo "Delete IP address $ip_id"
  scw instance ip delete "$ip_id"
else
  echo "WARN: IP address not deleted for instance $INSTANCE_NAME"
fi

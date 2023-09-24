#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

if [ $HOSTNAME=clrinfoport18 ]
then
  rsync --rsh='ssh -p 16042' -avz k8s0@178.170.42.15:/home/k8s0/ikoula-setup/* "$DIR"
else
  echo "ERROR: Run this command on clrinfoport18"
fi

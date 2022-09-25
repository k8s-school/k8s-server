#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

# WARN: Docker error
# 429 Too Many Requests - Server message: toomanyrequests: You have reached your pull rate limit. You may increase the limit by authenticating and upgrading: https://www.docker.com/increase-rate-limit

for ((i=0; i<=$NB_USER; i++))
do
    "$HOME/kind-helper/k8s-create.sh" -c "calico" -n "k8s$i"
done


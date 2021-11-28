#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

NB_USER=10

for ((i=0; i<=$NB_USER; i++))
do
    "$HOME/kind-helper/k8s-create.sh" -p -c "calico" -n "k8s$i"
done


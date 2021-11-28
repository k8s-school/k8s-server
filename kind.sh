#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

for ((i=0; i<=$NB_USER; i++))
do
    "$HOME/kind-helper/k8s-create.sh" -p -c "calico" -n "k8s$i"
done


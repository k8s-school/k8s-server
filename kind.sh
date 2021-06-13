#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

NB_USER=7

for ((i=0; i<=$NB_USER; i++))
do
    "$HOME/kind-helper/k8s-create.sh" -n "k8s$i"
done


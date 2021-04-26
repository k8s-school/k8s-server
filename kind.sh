#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

NB_USER=13

for ((i=0; i<=$NB_USER; i++))
do
    "$HOME/kind-travis-ci/k8s-create.sh" -n "k8s$i"
done


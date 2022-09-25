#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

for ((i=0; i<=$NB_USER; i++))
do
    kubectl create ns "k8s$i"
done


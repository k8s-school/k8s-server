#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

for ((i=1; i<=$NB_USER; i++))
do
    USER="k8s$i"
    sudo su - "$USER" -c "$(k8s-toolbox desk --show) gcloud auth login"
done"

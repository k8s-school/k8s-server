#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

NB_USER=13

for ((i=1; i<=$NB_USER; i++))
do
    rm -rf /home/k8s$i/k8s/homefs/*
done


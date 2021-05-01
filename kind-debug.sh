#!/bin/bash

set -euxo pipefail

NB_CLUSTER=13

for ((i=0; i<=$NB_CLUSTER; i++))
do
    kind create cluster --name "cluster-$i"
done


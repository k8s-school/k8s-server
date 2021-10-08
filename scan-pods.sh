#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

NB_USER=8

for ((i=0; i<=$NB_USER; i++))
do
    echo "------------ User $i" 
    kubectl config use-context "kind-k8s$i"
    kubectl get svc 
done
kubectl config use-context "kind-k8s0"

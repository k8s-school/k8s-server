#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh


for ((i=1; i<=$NB_USER; i++))
do
    USER="k8s$i"
    GCLOUD_CONFIG="/home/$USER/k8s/homefs/.config"

    if [ -d "$GCLOUD_CONFIG" ]; then
      sudo cp -prf "$GCLOUD_CONFIG" /tmp
    fi
    sudo rm -rf /home/$USER/*
    sudo rm -rf /home/$USER/.kube/*
    WORKDIR="/home/$USER/k8s/homefs"
    sudo mkdir -p "$WORKDIR"
    sudo chown $USER:$USER "$WORKDIR" 
    cd "$WORKDIR/.."
    sudo curl -lO https://raw.githubusercontent.com/k8s-school/k8s-toolbox/master/toolbox.sh
    sudo chmod +x toolbox.sh
    sudo chown $USER:$USER toolbox.sh
    if [ -d "/tmp/.config" ]; then
      sudo cp -prf /tmp/.config $GCLOUD_CONFIG
      sudo rm -rf /tmp/.config
    fi
done

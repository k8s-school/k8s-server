#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

for ((i=1; i<=$NB_USER; i++))
do
    echo "WARN: do not delete "homefs/.config" directory, rewrite the script"
    exit 1
    USER="k8s$i"
    sudo rm -rf /tmp/config
    if [ -d "/home/$USER/.config" ]; then
      sudo cp -rf /home/$USER/.config /tmp
    fi
    sudo rm -rf /home/$USER/*
    sudo rm -rf /home/$USER/.kube/*
    WORKDIR="/home/$USER/k8s"
    sudo mkdir "$WORKDIR"
    sudo chown $USER:$USER "$WORKDIR" 
    cd "$WORKDIR"
    sudo curl -lO https://raw.githubusercontent.com/k8s-school/k8s-toolbox/master/toolbox.sh
    sudo chmod +x toolbox.sh
    sudo chown $USER:$USER toolbox.sh
    if [ -d "/tmp/.config" ]; then
      sudo cp -rf /tmp/.config /home/$USER
    fi
done

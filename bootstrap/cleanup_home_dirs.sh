#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh


for ((i=1; i<=$NB_USER; i++))
do
    USER="k8s$i"
    GCLOUD_CONFIG="/home/$USER/.ktbx/homefs/.config"

    if [ -d "$GCLOUD_CONFIG" ]; then
      sudo cp -prf "$GCLOUD_CONFIG" /tmp
    fi
    sudo rm -rf /home/$USER
    sudo mkdir -p "/home/$USER/.kube"
    sudo chown -R $USER:$USER "/home/$USER"
    sudo mkdir -p "/home/$USER/.ktbx/homefs"
    sudo chown -R $USER:$USER "/home/$USER/.ktbx/homefs"

    if [ -d "/tmp/.config" ]; then
      sudo cp -prf /tmp/.config $GCLOUD_CONFIG
      sudo rm -rf /tmp/.config
    fi
done

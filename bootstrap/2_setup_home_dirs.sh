#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

# Test if os is ubuntu
distrib=$(lsb_release -si)
if [ $distrib == "Ubuntu" ]; then
  repo="k8s-school"
else
  repo="openshift-advanced"
fi

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
    if [ -d "/tmp/.config" ]; then
      sudo cp -prf /tmp/.config $GCLOUD_CONFIG
      sudo rm -rf /tmp/.config
    fi
    sudo su $USER sh -c "git clone https://github.com/k8s-school/$repo /home/$USER/.ktbx/homefs/$repo"
done

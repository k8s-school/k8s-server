#!/bin/bash

set -euxo pipefail

sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt update
sudo apt-get install     ca-certificates     curl     gnupg     lsb-release
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo apt-get update
sudo chmod a+r /etc/apt/keyrings/docker.gpg
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -a -G docker k8s0

echo "Clone sources"
sudo apt install git
git clone https://github.com/k8s-school/kind-helper.git
git clone https://github.com/k8s-school/k8s-toolbox.git

#!/bin/bash

set -euxo pipefail

sudo apt-get update -y
sudo apt-get install -y bash-completion git docker.io curl openssh-server

user="k8s0"
pass="changeme"

sudo adduser --disabled-password --gecos "" "$user"
sudo usermod -a -G docker "$user"
su - "$user" -c "git clone https://github.com/k8s-school/k8s-server.git"
echo "$user:$pass" | sudo chpasswd

echo "Add sudo access without password"
echo "$user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/"$user"

echo "Setup sshd"
sudo systemctl restart ssh

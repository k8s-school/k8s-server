#!/bin/bash

set -euxo pipefail

apt-get update -y
apt-get install -y bash-completion git docker.io

user="k8s"
pass="dede"

adduser "$user"
sudo usermod -a -G docker "$user"
su - "$user" -c "git clone https://github.com/k8s-school/ikoula-setup.git"
echo "$user:$pass" | chpasswd

# Add sudo access without password
echo "$user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$user"


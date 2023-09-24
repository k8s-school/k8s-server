#!/bin/bash

set -euxo pipefail

apt-get update -y
apt-get install -y bash-completion git docker.io

user="k8s0"
pass="changeme"

adduser --disabled-password --gecos "" "$user"
sudo usermod -a -G docker "$user"
su - "$user" -c "git clone https://github.com/k8s-school/ikoula-setup.git"
echo "$user:$pass" | chpasswd

echo "Add sudo access without password"
echo "$user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$user"

echo "Setup sshd"
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl sshd restart


#!/bin/bash

set -euxo pipefail

apt-get install -y bash-completion git

user="k8s"
pass="dede"

adduser "$user"
su - "$user" -c "git clone https://github.com/k8s-school/ikoula-setup.git"
echo "$user:$pass" | chpasswd

# Add sudo access without password
echo "$user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$user"


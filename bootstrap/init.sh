#!/bin/bash

# Launch remotely using the following command:
# curl -s https://raw.githubusercontent.com/k8s-school/openshift-advanced/main/init.sh | bash

set -euxo pipefail

dnf install -y bash-completion bind-utils git

user="k8s"
pass="dede"

adduser "$user"
su - "$user" -c "git clone https://github.com/k8s-school/ikoula-setup.git"
echo "$user:$pass" | chpasswd

# Add sudo access without password
echo "$user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$user"


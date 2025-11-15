#!/bin/bash

# Launch remotely using the following command:
# curl -s https://raw.githubusercontent.com/k8s-school/openshift-advanced/main/init.sh | bash

set -euxo pipefail

dnf install -y bash-completion bind-utils git

echo "Installing Cockpit..."
sudo dnf install -y cockpit
sudo systemctl enable --now cockpit.socket

user="k8s0"
pass="0p&nsh!ft"

adduser "$user"
su - "$user" -c "git clone https://github.com/k8s-school/openshift-advanced.git"
su - "$user" -c "git clone https://github.com/k8s-school/k8s-server.git"
su - "$user" -c "echo 'export PATH=/home/$user/bin:\$PATH' >> /home/$user/.bashrc"
echo "$user:$pass" | chpasswd

# Add sudo access without password
echo "$user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$user"

echo "Setup sshd"
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/50-cloud-init.conf
systemctl restart sshd

# Disable SELinux
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
setenforce Permissive



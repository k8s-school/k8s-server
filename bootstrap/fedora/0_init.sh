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
# BRANCH is propagated from the operator's local checkout by infra/start.sh.
if [ -z "${BRANCH:-}" ]; then
  echo "ERROR: BRANCH is not set" >&2
  exit 1
fi
# BRANCH is interpolated into the git command string; restrict it to safe chars.
if ! printf '%s' "$BRANCH" | grep -qE '^[A-Za-z0-9._/-]+$'; then
  echo "ERROR: branch name '$BRANCH' contains unsupported characters" >&2
  exit 1
fi
su - "$user" -c "git clone -b $BRANCH https://github.com/k8s-school/k8s-server.git"
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



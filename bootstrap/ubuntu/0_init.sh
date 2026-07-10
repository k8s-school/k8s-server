#!/bin/bash

set -euxo pipefail

sudo apt-get update -y
# Docker is installed later by 0.1_install_docker.sh (docker-ce from Docker's repo).
# Installing distro docker.io here conflicts with that and breaks docker.service.
sudo apt-get install -y bash-completion git curl openssh-server cockpit

sudo systemctl status cockpit.socket

user="k8s0"
pass="changeme"

sudo adduser --disabled-password --gecos "" "$user"
# docker group membership is granted by 0.1_install_docker.sh, once docker is installed.
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
echo "$user:$pass" | sudo chpasswd

echo "Add sudo access without password"
echo "$user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/"$user"

echo "Setup sshd"
sudo systemctl restart ssh

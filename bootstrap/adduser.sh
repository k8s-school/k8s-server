#!/bin/bash

# Shared user-provisioning script for all flavors.
# Usage: adduser.sh <prefix>
#   k8s      -> users k8s0..k8sN     (k8s / openshift trainings, k8s0 = instructor)
#   student  -> users student1..N    (otel training)
#
# Only creates the accounts + base home dirs. Per-user training repo, PORT_OFFSET
# and CLUSTER_NAME are handled afterwards by 2_setup_home_dirs.sh (which wipes and
# recreates the homes, so writing .bashrc here would be lost).

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

PREFIX="${1:?usage: adduser.sh <k8s|student>}"

# k8s0 is the instructor account; student accounts start at 1.
if [ "$PREFIX" = "k8s" ]; then
  start=0
else
  start=1
fi

# OS specifics: Ubuntu users get the adm group; Fedora needs an SELinux relabel
# of the docker-mounted dirs (svirt_sandbox_file_t).
if [ "$(lsb_release -si 2>/dev/null)" == "Ubuntu" ]; then
  groups="docker,adm"
  selinux=false
else
  groups="docker"
  selinux=true
fi

for ((i=start; i<=$NB_USER; i++))
do
  USER="${PREFIX}${i}"
  echo $USER
  id -u $USER &>/dev/null || sudo useradd "$USER" --create-home --groups "$groups" --shell /bin/bash
  echo "${USER}:${i}${PASS}" | sudo chpasswd
  sudo su "$USER" -c "mkdir -p /home/$USER/.kube && \
    mkdir -p /home/$USER/.ktbx/homefs"
  if [ "$selinux" = true ]; then
    sudo chcon -Rt svirt_sandbox_file_t "/home/$USER/.kube" "/home/$USER/.ktbx/homefs"
  fi
done

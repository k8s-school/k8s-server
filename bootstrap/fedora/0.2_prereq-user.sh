#!/bin/bash

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR"/../env.sh

sudo dnf install -y byobu

mkdir -p $HOME/src

echo "PATH=\$PATH:\$HOME/go/bin" >>~/.bashrc
echo "PATH=\$PATH:\$HOME/crc-linux-$CRC_VERSION-amd64" >>~/.bashrc

# SELinux setup
chcon -Rt svirt_sandbox_file_t $HOME/.kube
chcon -Rt svirt_sandbox_file_t $HOME/.ktbx/homefs
sudo chcon -Rt svirt_sandbox_file_t /etc/group
sudo chcon -Rt svirt_sandbox_file_t /etc/passwd

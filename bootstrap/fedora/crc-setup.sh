#!/bin/bash

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR"/../env.sh

if [ ! -e "$HOME/crc-linux-$CRC_VERSION-amd64" ]; then
    echo "crc-linux-$CRC_VERSION-amd64 not found, downloading..."
    # FIXME set a destination directory
    curl -Lo $HOME/crc-linux-amd64.tar.xz https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/$CRC_VERSION/crc-linux-amd64.tar.xz
    tar xvf $HOME/crc-linux-amd64.tar.xz --directory $HOME
    rm $HOME/crc-linux-amd64.tar.xz
else
    echo "crc-linux-$CRC_VERSION-amd64 found, skipping download..."
fi

mkdir -p $HOME/bin
ln -sf $HOME/crc-linux-$CRC_VERSION-amd64/crc  $HOME/bin/crc

export PATH=$HOME/bin:$PATH

echo "Preset openshift for crc..."
# $crc config set preset okd
crc config set preset openshift

echo "Setting up crc..."
crc config set cpus 7
crc config set memory 24576
# Required on Fedora 38
crc config set skip-check-daemon-systemd-unit true
crc config set skip-check-daemon-systemd-sockets true
# Enable cluster monitoring if true
# this require at least 14 GiB of memory (a value of 14336)
crc config set enable-cluster-monitoring false
crc setup

# Set the libvirt service to start at boot
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service

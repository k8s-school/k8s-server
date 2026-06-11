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

# crc setup configures systemd *user* units, which requires a running user
# systemd instance (and its session/DBus bus). Over SSH or in a non-login
# shell those are missing, and crc fails with:
#   Failed to connect to user scope bus via local transport ...
#   $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined
# Enabling linger starts the user systemd instance at boot (and now), and we
# point the env vars at its runtime dir so this works non-interactively.
sudo loginctl enable-linger "$USER"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

echo "Preset openshift for crc..."
# $crc config set preset okd
crc config set preset openshift

echo "Setting up crc..."
crc config set cpus 7
crc config set memory 24576
# Enable cluster monitoring if true
# this require at least 14 GiB of memory (a value of 14336)
crc config set enable-cluster-monitoring false
crc config set disk-size 50

# Provide the pull secret up front so that `crc start` never prompts for it
# interactively. infra/start.sh scp's pull-secret.txt into the user's home.
PULL_SECRET_FILE="$HOME/pull-secret.txt"
if [ -f "$PULL_SECRET_FILE" ]; then
    echo "Configuring crc pull secret from $PULL_SECRET_FILE..."
    chmod 600 "$PULL_SECRET_FILE"
    crc config set pull-secret-file "$PULL_SECRET_FILE"
else
    echo "WARNING: $PULL_SECRET_FILE not found, crc will prompt for the pull secret."
fi

crc setup

# Set the libvirt service to start at boot
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service

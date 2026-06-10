#!/bin/bash

# Ubuntu 24.04 preparation script for Red Hat OpenShift Local (CRC)
# Purpose: Configure virtualization, resolve dependencies, and clear port conflicts.
# Target Environment: Ubuntu 24.04 LTS (Noble Numbat)

set -e

echo "--- 1. Installing System Dependencies ---"
# bridge-utils and network-manager are required for the CRC networking stack
# virtiofsd is mandatory for file sharing between host and VM on recent kernels
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
                    bridge-utils network-manager virtiofsd

echo "--- 2. Configuring User Permissions ---"
# Add the current user to the libvirt group to manage VMs without constant sudo
sudo usermod -aG libvirt $USER

newgrp libvirt

echo "--- 4. Resolving Port Conflicts (Port 443) ---"
# CRC's daemon attempts to bind to port 443 to expose the OpenShift console.
# We stop HAProxy if it's running to prevent the 'address already in use' error.
if systemctl is-active --quiet haproxy; then
    echo "Stopping HAProxy to release port 443..."
    sudo systemctl stop haproxy
else
    echo "Port 443 appears to be available (HAProxy is not active)."
fi

echo "--- 5. Initializing Virtualization Services ---"
# Ensure the libvirt daemon is enabled and running
sudo systemctl enable --now libvirtd
sudo systemctl restart libvirtd

echo "-------------------------------------------------------"
echo "Prerequisites installed successfully!"
echo "IMPORTANT: You MUST log out and log back in (or restart)"
echo "for the 'libvirt' group membership to take effect."
echo "-------------------------------------------------------"

#!/bin/bash

set -euxo pipefail

sudo dnf install -y docker lsb_release
sudo usermod -a -G docker $USER
# newgrp docker
sudo systemctl start docker


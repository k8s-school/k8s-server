#!/bin/bash

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR"/../env.sh


export PATH=$HOME/bin:$PATH

echo "Starting crc daemon..."
crc daemon &

echo "Starting crc..."
crc start

sudo cp "$HOME/.crc/bin/oc/oc" "/usr/local/bin/"

# Installing oc-mirror
git clone https://github.com/openshift/oc-mirror.git /tmp/oc-mirror
cd /tmp/oc-mirror
make clean
make tidy
make build
sudo cp /tmp/oc-mirror/bin/oc-mirror /usr/local/bin/


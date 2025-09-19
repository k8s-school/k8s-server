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

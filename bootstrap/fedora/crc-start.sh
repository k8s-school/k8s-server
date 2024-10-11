#!/bin/bash

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR"/../env.sh

crc="$HOME/crc-linux-$CRC_VERSION-amd64"/crc

echo "Starting crc..."
$crc start

sudo cp "$HOME/.crc/bin/oc/oc" "/usr/local/bin/"

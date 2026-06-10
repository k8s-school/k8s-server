#!/bin/bash

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR"/../env.sh

sudo cp "$HOME/.crc/bin/oc/oc" "/usr/local/bin/"


# Install oc-mirror from OpenShift mirror
OC_MIRROR_URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/oc-mirror.tar.gz"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "$OC_MIRROR_URL" -o "$TMP_DIR/oc-mirror.tar.gz"
tar -xzf "$TMP_DIR/oc-mirror.tar.gz" -C "$TMP_DIR"
chmod +x "$TMP_DIR/oc-mirror"
sudo install -m 0755 "$TMP_DIR/oc-mirror" /usr/local/bin/oc-mirror

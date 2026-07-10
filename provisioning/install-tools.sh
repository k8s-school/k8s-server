#!/bin/bash

# Install the provisioning toolchain (OpenTofu, Packer, Ansible, ansible-lint)
# on the operator workstation. Idempotent: skips anything already at the pinned
# version. Installs into $PREFIX/bin (no sudo needed by default).
#
# Usage:
#   ./install-tools.sh                 # into ~/.local/bin
#   PREFIX=/usr/local sudo ./install-tools.sh   # system-wide

set -euo pipefail

OPENTOFU_VERSION="${OPENTOFU_VERSION:-1.8.5}"
PACKER_VERSION="${PACKER_VERSION:-1.11.2}"

PREFIX="${PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin"
mkdir -p "$BIN"

case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "ERROR: unsupported arch $(uname -m)" >&2; exit 1 ;;
esac
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

have_version() { command -v "$1" >/dev/null 2>&1 && "$1" version 2>/dev/null | grep -q "$2"; }

install_zip() { # name version url
  local name="$1" want="$2" url="$3"
  if have_version "$name" "$want"; then
    echo "== $name $want already installed, skipping"
    return
  fi
  echo "== installing $name $want"
  curl -fSL "$url" -o "$tmp/$name.zip"
  unzip -oq "$tmp/$name.zip" -d "$tmp/$name"
  install -m 0755 "$tmp/$name/$name" "$BIN/$name"
}

install_zip tofu "$OPENTOFU_VERSION" \
  "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_${OS}_${ARCH}.zip"

install_zip packer "$PACKER_VERSION" \
  "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_${OS}_${ARCH}.zip"

# Ansible + ansible-lint via pipx (PEP 668 friendly on Ubuntu 24.04).
if ! command -v pipx >/dev/null 2>&1; then
  echo "== installing pipx"
  python3 -m pip install --user --break-system-packages pipx
  python3 -m pipx ensurepath >/dev/null 2>&1 || true
fi

export PATH="$BIN:$PATH"
pipx install --force ansible-core >/dev/null
pipx install --force ansible-lint >/dev/null

# Galaxy collection used by the participants role (sefcontext).
if command -v ansible-galaxy >/dev/null 2>&1; then
  ansible-galaxy collection install community.general >/dev/null
fi

echo
echo "Installed into $BIN :"
for b in tofu packer ansible ansible-lint; do
  printf '  %-14s ' "$b"; command -v "$b" >/dev/null && "$b" --version 2>/dev/null | head -1 || echo "MISSING"
done
echo
echo "Ensure $BIN is on your PATH (pipx bins land in ~/.local/bin)."

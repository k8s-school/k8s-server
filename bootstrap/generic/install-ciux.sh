#!/bin/bash

set -euxo pipefail

# Install kubectl and setup auto-completion
go install github.com/k8s-school/ciux@v0.0.1-rc11
sudo cp "$HOME/go/bin/ciux" "/usr/local/bin"

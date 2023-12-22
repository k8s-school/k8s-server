#!/bin/bash

set -euxo pipefail

# Install kubectl and setup auto-completion
go install github.com/k8s-school/ciux@v1.1.1-rc6
sudo cp "$HOME/go/bin/ciux" "/usr/local/bin"
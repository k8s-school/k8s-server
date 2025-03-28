#!/bin/bash

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Go may just have been installed
export PATH=/usr/local/go/bin:$PATH

mkdir -p $HOME/src

# Install kubectl and setup auto-completion
go install github.com/k8s-school/ktbx@v1.1.4-rc6
sudo cp "$HOME/go/bin/ktbx" "/usr/local/bin"
go install -v github.com/k8s-school/ink@v0.0.1-rc3
sudo cp "$HOME/go/bin/ink" "/usr/local/bin"

ktbx install kind
ktbx install kubectl
echo 'source <(kubectl completion bash)' >>~/.bashrc

# Setup kubectl aliases
curl -Lo $HOME/.kubectl_aliases https://raw.githubusercontent.com/ahmetb/kubectl-alias/master/.kubectl_aliases
echo '[ -f ~/.kubectl_aliases ] && source ~/.kubectl_aliases' >>~/.bashrc

mkdir -p $HOME/.kube
mkdir -p $HOME/.ktbx/homefs

#!/bin/bash

set -euxo pipefail

# See https://github.com/kubernetes-sigs/kind/issues/2219
# sudo sysctl fs.inotify.max_user_watches=524288
# sudo sysctl fs.inotify.max_user_instances=512

# Add these to /etc/sysctl.conf
cat <<EOF | sudo tee -a /etc/sysctl.conf
# See https://github.com/kubernetes-sigs/kind/issues/2219
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=1024
EOF

# Apply the changes
sudo sysctl -p

#!/bin/bash

set -euxo pipefail

# See https://github.com/kubernetes-sigs/kind/issues/2219
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

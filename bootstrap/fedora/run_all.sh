#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

$DIR/../install-go.sh
$DIR/../install-godeps.sh
$DIR/../upgrade-sysctl.sh
$DIR/0.1_install_docker.sh
$DIR/1_addusers.sh
$DIR/../2_setup_home_dirs.sh
ktbx create

# TODO
# $DIR/../docker_load.sh

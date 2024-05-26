#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

$DIR/../install-go.sh
# Source path to golang
. ~/.bashrc
$DIR/../install-godeps.sh
$DIR/1_addusers.sh
$DIR/2_setup_home_dirs.sh


$DIR/0.1_install_docker.sh
ktbx create

$DIR/../docker_load.sh
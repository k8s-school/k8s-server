#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

# Flavor propagated over ssh by infra/start.sh (k8s or otel for ubuntu),
# inherited by the sub-scripts (adduser.sh, 2_setup_home_dirs.sh).
FLAVOR="${FLAVOR:-k8s}"

# Common tooling: go, ktbx, kind, kubectl (installed system-wide in /usr/local/bin).
$DIR/../install-go.sh
$DIR/../install-godeps.sh

$DIR/../upgrade-sysctl.sh
# Docker must be installed before the participant accounts are created: adduser.sh
# adds them to the 'docker' group, which only exists once docker is installed.
$DIR/0.1_install_docker.sh

# Participant accounts (k8sN for k8s, studentN for otel) + per-user home/repo.
if [ "$FLAVOR" = "otel" ]; then
  $DIR/../adduser.sh student
else
  $DIR/../adduser.sh k8s
fi
$DIR/../2_setup_home_dirs.sh

if [ "$FLAVOR" = "otel" ]; then
  # otel: helm for the demo; each student creates their own cluster via `up.sh -c`.
  ktbx install helm
else
  # k8s: instructor cluster (participants create their own during the labs).
  ktbx create
fi

# TODO
# $DIR/../docker_load.sh

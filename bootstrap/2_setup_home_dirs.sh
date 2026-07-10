#!/bin/bash

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/env.sh

# Per-flavor participant repo and account naming. FLAVOR is exported by
# run_all.sh (propagated over ssh by infra/start.sh); default to k8s.
FLAVOR="${FLAVOR:-k8s}"
case "$FLAVOR" in
  k8s)       prefix="k8s";     repo="k8s-school";        dest=".ktbx/homefs/k8s-school" ;;
  openshift) prefix="k8s";     repo="openshift-advanced"; dest=".ktbx/homefs/openshift-advanced" ;;
  otel)      prefix="student"; repo="otel";              dest=".ktbx/homefs/otel" ;;
  *) echo "ERROR: unknown FLAVOR '$FLAVOR'" >&2; exit 1 ;;
esac

# Start at 1: the instructor account (k8s0) must never be wiped, it holds the
# k8s-server clone this bootstrap runs from.
for ((i=1; i<=$NB_USER; i++))
do
    USER="${prefix}$i"
    GCLOUD_CONFIG="/home/$USER/.ktbx/homefs/.config"

    # Preserve a participant's gcloud login across re-provisioning.
    if [ -d "$GCLOUD_CONFIG" ]; then
      sudo cp -prf "$GCLOUD_CONFIG" /tmp
    fi
    sudo rm -rf /home/$USER
    sudo mkdir -p "/home/$USER/.kube"
    sudo chown -R $USER:$USER "/home/$USER"
    if [ -d "/tmp/.config" ]; then
      sudo cp -prf /tmp/.config $GCLOUD_CONFIG
      sudo rm -rf /tmp/.config
    fi
    sudo su $USER sh -c "git clone https://github.com/k8s-school/$repo /home/$USER/$dest"

    # Per-user training environment: a dedicated cluster name and a PORT_OFFSET so
    # port-forwards never collide on the shared server (used by the otel up.sh,
    # harmless for the other flavors).
    offset=$((i * 100))
    sudo su $USER sh -c "cat >> /home/$USER/.bashrc <<EOF

# Training environment
export CLUSTER_NAME=$USER
export PORT_OFFSET=$offset
EOF"
done

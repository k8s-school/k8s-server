#!/bin/bash

# Install Kubernetes on the kubeadm lab clusters booted by `make cluster`, for
# the labs which start from an installed cluster (kubeadm-upgrade).
#
# Runs the kubeadm lab page of k8s-school-labs itself, with its ci/mdlab.py:
# the page is the install script, so the clusters are exactly what a
# participant gets by following it, in the version it pins. One run per
# participant, all at the same time, from the trainer's workstation: the nodes
# accept the operator key that Scaleway injects from the project.
#
# Usage: util/cluster-install.sh '<node_ips json>'   (see `make cluster-install`)
#   LABS_DIR=<k8s-school-labs checkout>   use it instead of a fresh clone
#   LOG_DIR=<dir>                         one log per participant

set -euo pipefail

NODE_IPS=$1
LOG_DIR=${LOG_DIR:-tofu/clusters/install-logs}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ -z "${LABS_DIR:-}" ]; then
  git clone -q --depth 1 https://github.com/k8s-school/k8s-school-labs "$work/labs"
  LABS_DIR=$work/labs
fi
page=$LABS_DIR/content/1_Labs/kubeadm.en.md

# Without the ci-host markers (a page older than 2026-11-01), mdlab would run
# the commands of the page here, on the trainer's workstation, not on the nodes.
if ! grep -q '^<!-- ci-host: ' "$page"; then
  echo "ERROR: $page has no ci-host marker: its commands would run on this machine. Use a recent k8s-school-labs."
  exit 1
fi

# The page names the nodes $USER-1 and $USER-2: an ssh config resolves these
# names, with a known_hosts of its own since Scaleway recycles addresses.
{
  jq -r 'to_entries[] | "Host \(.key)\n  HostName \(.value)"' <<<"$NODE_IPS"
  printf 'Host *\n  User ubuntu\n  UserKnownHostsFile %s\n  StrictHostKeyChecking accept-new\n  ConnectTimeout 10\n  ServerAliveInterval 15\n  ServerAliveCountMax 8\n' \
    "$work/known_hosts"
} > "$work/ssh_config"

nodes=$(jq -r 'keys[]' <<<"$NODE_IPS")
students=$(sed 's/-[12]$//' <<<"$nodes" | sort -u)

echo "Waiting for ssh on every node"
for node in $nodes; do
  timeout 300 sh -c "until ssh -F '$work/ssh_config' '$node' true 2>/dev/null; do sleep 5; done" \
    || { echo "ERROR: no ssh on $node after 5 minutes"; exit 1; }
done

mkdir -p "$LOG_DIR"
declare -A pids
for s in $students; do
  echo "Installing the cluster of $s (log: $LOG_DIR/$s.log)"
  USER=$s MDLAB_SSH="ssh -F $work/ssh_config" \
    python3 "$LABS_DIR/ci/mdlab.py" run -x "$page" </dev/null >"$LOG_DIR/$s.log" 2>&1 &
  pids[$s]=$!
done

failed=()
for s in $students; do
  if wait "${pids[$s]}"; then
    echo "$s: OK"
  else
    echo "$s: FAILED, see $LOG_DIR/$s.log"
    failed+=("$s")
  fi
done

if [ ${#failed[@]} -ne 0 ]; then
  echo "Failed: ${failed[*]}. Rebuild a cluster with 'make cluster-down' and 'make cluster', or 'sudo kubeadm reset' on its nodes."
  exit 1
fi

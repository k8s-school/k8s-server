#!/bin/bash

# Create a new instance on Scaleway

# Launch remotely using the following command:
# curl -s https://raw.githubusercontent.com/k8s-school/openshift-advanced/main/0_setup.sh | bash

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

bootstrap_dir="/home/$K8S_USER/k8s-server/bootstrap"

. $DIR/env.sh

if scw instance server list | grep $INSTANCE_NAME; then
  echo "ERROR: Instance $INSTANCE_NAME already exists" >&2
  exit 1
fi

ip_id=$(scw instance ip list tags.0="$INSTANCE_NAME" | grep -w "$INSTANCE_NAME" |   awk '{print $1}' || echo "")
echo "Using existing IP adress $ip_id"
if [ -n "$ip_id" ]
then
  echo "Using existing IP adress $ip_id"
else
  ip_id=$(scw instance ip create tags.0="$INSTANCE_NAME" | egrep "^ID" |  awk '{print $2}')
fi

scw instance server create zone="fr-par-1" image=$DISTRIBUTION type="$INSTANCE_TYPE" ip="$ip_id" name=$INSTANCE_NAME root-volume=local:100GB
instance_id=$(scw instance server list | grep $INSTANCE_NAME | awk '{print $1}')
ip_address=$(scw instance server wait "$instance_id" | grep PublicIP.Address | awk '{print $2}')


ssh-keygen -f "/home/fjammes/.ssh/known_hosts" -R "$ip_address"
until ssh -o "StrictHostKeyChecking no" root@"$ip_address" true 2> /dev/null
  do
    echo "Waiting for sshd on $ip_address..."
    sleep 5
done

ssh root@"$ip_address" -- "curl  -s https://raw.githubusercontent.com/k8s-school/k8s-server/main/bootstrap/ubuntu/init.sh | bash"
ssh root@"$ip_address" -- "su - $K8S_USER -c '$bootstrap_dir/ubuntu/run_all.sh'"


echo "Connect to the server with below command:"
echo "ssh k8s0@$ip_address"


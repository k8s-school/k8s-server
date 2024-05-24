#!/bin/bash

# Display the ssh command to connect to the instance

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. $DIR/env.sh

instance_id=$(scw instance server list | grep $INSTANCE_NAME | awk '{print $1}')
ip_address=$(scw instance server wait "$instance_id" | grep PublicIP.Address | awk '{print $2}')

echo "$ip_address"

#!/bin/bash

# Display the ssh command to connect to the instance

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. $DIR/env.sh

ip_address=$(scw instance ip list tags.0="$INSTANCE_NAME" | grep "$INSTANCE_NAME" |   awk '{print $2}')

echo "$ip_address"

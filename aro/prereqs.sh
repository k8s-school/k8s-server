#!/bin/bash

# Prerequisites for the ARO scripts in this directory.
# Run this once per shell session before create.sh / teardown.sh.
#
# - Installs the Azure CLI if missing (requires sudo)
# - Logs in with the service principal from ~/.azure/osServicePrincipal.json
# - Registers the Azure resource providers required by ARO
# - Sanity-checks Microsoft Graph access for the service principal
# - Checks vCPU quota in the target region against the VM sizes create.sh requests

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR/env.sh"

SP_FILE="${AZURE_SP_FILE:-$HOME/.azure/osServicePrincipal.json}"

# --- Azure CLI ---
if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI not found, installing (requires sudo)..."
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash -s -- -y
fi

# --- Login with service principal ---
if [ ! -f "$SP_FILE" ]; then
  echo "ERROR: service principal file not found: $SP_FILE" >&2
  exit 1
fi

read -r CLIENT_ID TENANT_ID SUBSCRIPTION_ID < <(
  python3 -c "
import json
d = json.load(open('$SP_FILE'))
print(d['clientId'], d['tenantId'], d['subscriptionId'])
"
)

SECRET_FILE=$(mktemp)
trap 'rm -f "$SECRET_FILE"' EXIT
python3 -c "import json; print(json.load(open('$SP_FILE'))['clientSecret'], end='')" > "$SECRET_FILE"
chmod 600 "$SECRET_FILE"

echo "Logging in as service principal $CLIENT_ID..."
az login --service-principal -u "$CLIENT_ID" -p "@$SECRET_FILE" --tenant "$TENANT_ID" -o none
rm -f "$SECRET_FILE"
az account set --subscription "$SUBSCRIPTION_ID"

# --- Resource providers ---
for ns in Microsoft.RedHatOpenShift Microsoft.Compute Microsoft.Storage Microsoft.Authorization Microsoft.Network; do
  state=$(az provider show -n "$ns" --query registrationState -o tsv)
  if [ "$state" != "Registered" ]; then
    echo "Registering $ns (current state: $state)..."
    az provider register --namespace "$ns" --wait
  fi
done

# --- Microsoft Graph access check ---
# az aro create looks up the ARO resource provider's service principal via
# Microsoft Graph. This requires the "Directory Readers" directory role (or
# Application.Read.All) on this service principal, which a Global
# Administrator must grant once per tenant:
#
#   az login   (with an admin account)
#   az rest --method POST --uri "https://graph.microsoft.com/v1.0/directoryRoles" \
#     --body '{"roleTemplateId": "88d8e3e3-8f55-4a1e-953a-9b9898b8876b"}'
#   az rest --method POST \
#     --uri "https://graph.microsoft.com/v1.0/directoryRoles(roleTemplateId='88d8e3e3-8f55-4a1e-953a-9b9898b8876b')/members/\$ref" \
#     --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/servicePrincipals/<SP_OBJECT_ID>\"}"
if ! az ad sp list --filter "appId eq '$CLIENT_ID'" -o none 2>/dev/null; then
  cat >&2 <<EOF
ERROR: service principal $CLIENT_ID cannot read Microsoft Graph
(directoryObjects). az aro create will fail with
"Authorization_RequestDenied: Insufficient privileges".

Fix: have a tenant Global Administrator grant the "Directory Readers" role
to this service principal. See the comment above this check in $0.
EOF
  exit 1
fi

# create.sh registers a per-cluster Azure AD application (the cluster's
# service principal) and a credential for it via Microsoft Graph. This
# requires the "Application Administrator" directory role on this service
# principal, which a Global Administrator must grant once per tenant:
#
#   az login   (with an admin account)
#   az rest --method POST --uri "https://graph.microsoft.com/v1.0/directoryRoles" \
#     --body '{"roleTemplateId": "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3"}'
#   az rest --method POST \
#     --uri "https://graph.microsoft.com/v1.0/directoryRoles(roleTemplateId='9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3')/members/\$ref" \
#     --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/servicePrincipals/<SP_OBJECT_ID>\"}"
SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv)
if ! az rest --method GET \
     --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/memberOf" \
     --query "value[?displayName=='Application Administrator']" -o tsv 2>/dev/null | grep -q .; then
  cat >&2 <<EOF
ERROR: service principal $CLIENT_ID is missing the "Application Administrator"
directory role. create.sh will fail with "Insufficient privileges" while
creating the cluster's service principal credential.

Fix: have a tenant Global Administrator grant this role to the service
principal (object id $SP_OBJECT_ID). See the comment above this check in $0.
EOF
  exit 1
fi

# --- vCPU quota check ---
echo "Checking vCPU quota in $LOCATION for $MASTER_COUNT x $MASTER_VM_SIZE (master) + $WORKER_COUNT x $WORKER_VM_SIZE (worker)..."
python3 - "$LOCATION" "$MASTER_VM_SIZE" "$WORKER_VM_SIZE" "$MASTER_COUNT" "$WORKER_COUNT" <<'PYEOF'
import json
import subprocess
import sys

location, master_size, worker_size, master_count, worker_count = sys.argv[1:6]
master_count, worker_count = int(master_count), int(worker_count)


def sku_info(size):
    out = subprocess.check_output([
        "az", "vm", "list-skus", "-l", location, "--size", size,
        "--query", "[0].{family:family, caps:capabilities}", "-o", "json",
    ])
    info = json.loads(out)
    if not info:
        sys.exit(f"ERROR: VM size {size} not found in {location}")
    vcpus = next(int(c["value"]) for c in info["caps"] if c["name"] == "vCPUs")
    return info["family"], vcpus


master_family, master_vcpus = sku_info(master_size)
worker_family, worker_vcpus = sku_info(worker_size)

needed_total = master_count * master_vcpus + worker_count * worker_vcpus
needed_by_family = {}
needed_by_family[master_family] = needed_by_family.get(master_family, 0) + master_count * master_vcpus
needed_by_family[worker_family] = needed_by_family.get(worker_family, 0) + worker_count * worker_vcpus

usage = json.loads(subprocess.check_output(["az", "vm", "list-usage", "-l", location, "-o", "json"]))
usage_by_name = {u["name"]["value"]: u for u in usage}

ok = True


def check(name_value, label, needed):
    global ok
    u = usage_by_name.get(name_value)
    if u is None:
        print(f"WARN: quota '{name_value}' not found, skipping check for {label}")
        return
    available = int(u["limit"]) - int(u["currentValue"])
    status = "OK" if available >= needed else "FAIL"
    if status == "FAIL":
        ok = False
    print(f"{status}: {label}: need {needed}, available {available} "
          f"(limit {u['limit']}, in use {u['currentValue']})")


check("cores", "Total regional vCPUs", needed_total)
for family, needed in needed_by_family.items():
    check(family, f"{family} vCPUs", needed)

if not ok:
    print(file=sys.stderr)
    print("ERROR: insufficient vCPU quota for the ARO cluster in "
          f"{location}. Request a quota increase via the Azure portal "
          "(Subscriptions > Usage + quotas) for the items marked FAIL "
          "above, then re-run this script.", file=sys.stderr)
    sys.exit(1)
PYEOF

echo
echo "All prerequisites met. You can now run: $DIR/create.sh"

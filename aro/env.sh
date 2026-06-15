# Configuration for the Azure Red Hat OpenShift (ARO) cluster

RESOURCE_GROUP="aro-rg"
LOCATION="francecentral"
CLUSTER_NAME="aro"
VNET_NAME="aro-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"

VNET_CIDR="10.0.0.0/22"
MASTER_CIDR="10.0.0.0/23"
WORKER_CIDR="10.0.2.0/23"

# VM sizes (az aro create defaults are documented but not always applied,
# so set them explicitly). ARO always provisions 3 master nodes.
# DSv3 family chosen for quota availability in francecentral.
MASTER_VM_SIZE="${MASTER_VM_SIZE:-Standard_D8s_v3}"
WORKER_VM_SIZE="${WORKER_VM_SIZE:-Standard_D4s_v3}"
WORKER_COUNT="${WORKER_COUNT:-3}"
MASTER_COUNT=3

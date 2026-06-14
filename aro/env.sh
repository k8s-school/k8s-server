# Configuration for the Azure Red Hat OpenShift (ARO) cluster

RESOURCE_GROUP="aro-rg"
LOCATION="westeurope"
CLUSTER_NAME="aro"
VNET_NAME="aro-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"

VNET_CIDR="10.0.0.0/22"
MASTER_CIDR="10.0.0.0/23"
WORKER_CIDR="10.0.2.0/23"

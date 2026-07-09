# k8s-server

Create and configure a kind-based k8s cluster.

# Requirement

- `scw` client: https://github.com/scaleway/scaleway-cli

```bash
git clone https://github.com/k8s-school/k8s-server.git
cd k8s-server/infra

# Pick the machine flavor by editing infra/conf.sh (FLAVOR=...):
#   k8s        Ubuntu + docker/kind/ktbx, shared k8sN accounts (Kubernetes training)
#   openshift  Fedora + crc (OpenShift training)
#   otel       Ubuntu + docker/kind/ktbx + helm, one account+cluster per student
#              (OpenTelemetry training, provisioned via the otel repo)
./start.sh          # -h for help
./terminate.sh -d
```

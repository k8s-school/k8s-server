# Machine flavor to launch, sourced by start.sh / terminate.sh / get_ip.sh.
# This replaces the former "env.sh" symlink: pick a flavor here, the matching
# env.$FLAVOR.sh is then sourced automatically.
#
# Available flavors:
#   k8s        Ubuntu, docker/kind/ktbx, shared k8sN accounts (Kubernetes training)
#   openshift  Fedora, crc (OpenShift training)
#   otel       Ubuntu, docker/kind/ktbx + helm, one account+cluster per student
#              (OpenTelemetry training, provisioned via the otel repo)
FLAVOR=k8s

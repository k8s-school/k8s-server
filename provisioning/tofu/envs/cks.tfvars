flavor        = "cks"
instance_name = "cks"

# 6 participants + the trainer, one kind cluster each. ktbx creates 4 nodes per
# cluster (1 control plane + its default of 3 workers), so 28 kind nodes plus
# 7 Guacamole XFCE desktops. Not measured yet: GP1-M (16 vCPU / 64 GiB) held one
# such cluster running all the CKS labs in turn with 60 GiB free (2026-10-21).
# Run util/sizing-report.sh during the first session and adjust.
instance_type = "GP1-M"

# No image_id: the cks flavor boots the k8s image (same tooling), resolved by
# its 'flavor=k8s' tag — see IMAGE_FLAVOR in the Makefile.

# Every kind node keeps its own copy of the preloaded images (falco, kube-bench...):
# 28 nodes instead of 4 is what makes the disk the first resource to watch.
root_volume_size_gb = 200

# Same public name as the other trainings: only one server runs at a time.
dns_zone      = "k8s-school.fr"
dns_subdomain = "training"

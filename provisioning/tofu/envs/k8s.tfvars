flavor        = "k8s"
instance_name = "k8s"
instance_type = "GP1-M"
# No image_id: `make up` finds the baked image by its 'flavor=k8s' tag and
# injects it. Build one first: `make create-image FLAVOR=k8s`. No fallback
# distro — without a baked image `make up` refuses to run.
root_volume_size_gb = 100

# Public name of the training server: training.k8s-school.fr, A record created
# in the OVH-hosted zone and pointed at the reserved IP. This is what turns on
# HTTPS for Guacamole — remove it and the stack falls back to plain HTTP.
dns_zone      = "k8s-school.fr"
dns_subdomain = "training"

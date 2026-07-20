flavor         = "k8s"
instance_name  = "k8s"
instance_type  = "GP1-M"
# No image_id: `make up` finds the baked image by its 'flavor=k8s' tag and
# injects it. Build one first: `make create-image FLAVOR=k8s`. No fallback
# distro — without a baked image `make up` refuses to run.
root_volume_size_gb = 100

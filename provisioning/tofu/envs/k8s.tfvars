flavor         = "k8s"
instance_name  = "k8s"
instance_type  = "GP1-M"
fallback_image = "ubuntu_noble"
# No image_id: `make up` finds the baked image by its 'flavor=k8s' tag
# (build one with `make create-image FLAVOR=k8s`), else boots fallback_image.
root_volume_size_gb = 100

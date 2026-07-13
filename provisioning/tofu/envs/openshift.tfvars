flavor         = "openshift"
instance_name  = "openshift"
instance_type  = "GP1-M"
fallback_image = "fedora" # TODO: pin the exact Fedora image label used by crc
# No image_id: `make up` finds the baked image by its 'flavor=openshift' tag
# (build one with `make create-image FLAVOR=openshift`), else boots fallback_image.
root_volume_size_gb = 100

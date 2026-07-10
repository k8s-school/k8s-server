flavor         = "openshift"
instance_name  = "openshift"
instance_type  = "GP1-M"
fallback_image = "fedora" # TODO: pin the exact Fedora image label used by crc
# image_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # TODO: from `packer build -var flavor=openshift`
root_volume_size_gb = 100

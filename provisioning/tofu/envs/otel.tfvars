flavor         = "otel"
instance_name  = "otel"
instance_type  = "GP1-M"
fallback_image = "ubuntu_noble"
# No image_id here: `make up` finds the baked image by its 'flavor=otel' tag
# (build one with `make create-image FLAVOR=otel`). Without one it boots
# fallback_image. Override manually if needed: tofu apply -var image_id=<id>.
root_volume_size_gb = 100

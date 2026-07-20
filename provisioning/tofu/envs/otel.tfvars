flavor         = "otel"
instance_name  = "otel"
instance_type  = "GP1-M"
# No image_id here: `make up` finds the baked image by its 'flavor=otel' tag and
# injects it. Build one first: `make create-image FLAVOR=otel`. There is no
# fallback distro — without a baked image `make up` refuses to run.
root_volume_size_gb = 100

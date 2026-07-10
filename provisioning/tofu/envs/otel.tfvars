flavor         = "otel"
instance_name  = "otel"
instance_type  = "GP1-M"
fallback_image = "ubuntu_noble"
# Freshly built by `packer build -var flavor=otel`. Ephemeral: regenerated each
# session (GHA auto-PR bumps it); delete with `make delete-image FLAVOR=otel`.
image_id = "f72ba484-5cb9-4e2a-b883-da3ffcd9e1b5"
root_volume_size_gb = 100

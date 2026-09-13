flavor        = "otel"
instance_name = "otel"

# Session-sized machine: 10 participants + the trainer account, one kind cluster
# each. Measured on a running stack (28 demo pods + load generator + the lab 2
# review-service): 6.5 GiB of RAM, 0.89 vCPU and 20 GB of disk per stack. With
# the Guacamole XFCE desktop on top that is ~8.5 GiB and 21 GB per participant,
# so 11 stacks need ~100 GiB of RAM (~115 at the lab 2 peak, when ten Maven JVMs
# build at once), ~255 GB of disk and ~12 vCPU in steady state.
#
# GP1-L (32 vCPU / 128 GiB, 0.774 EUR/h) is the cheapest type that fits: at
# equal RAM, POP2-HM-16C-128G costs more (0.824) and gives half the vCPU, which
# is what absorbs those ten simultaneous builds. See otel-labs'
# NOTE-dimensionnement-serveur.md for the full reasoning.
#
# Validating the labs on your own? Use the smaller sibling instead:
#   make provision FLAVOR=otel SIZE=small NB_USERS=2
instance_type = "GP1-L"

# No image_id here: `make up` finds the baked image by its 'flavor=otel' tag and
# injects it. Build one first: `make create-image FLAVOR=otel`. There is no
# fallback distro — without a baked image `make up` refuses to run.

# Measured 2026-09-13: 198 GB used with 9 accounts after every lab and two
# rebuilds, ~21 GB per participant, so ~240 GB at 11. 300 left 30 GB for two
# days of deploy.sh; 400 is the margin. This volume is what runs out first —
# long before the RAM does — and block storage is cheap.
root_volume_size_gb = 400

# Public name of the training server: training.k8s-school.fr, A record created
# in the OVH-hosted zone and pointed at the reserved IP. This is what turns on
# HTTPS for Guacamole — remove it and the stack falls back to plain HTTP.
dns_zone      = "k8s-school.fr"
dns_subdomain = "training"

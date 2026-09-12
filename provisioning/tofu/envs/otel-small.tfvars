# Validation-sized twin of otel-large.tfvars: same flavor, same baked image, same
# group_vars, same reserved IP and same public name — only the machine is
# smaller. For rehearsing the labs alone (or with one other person) before the
# session, without paying for the room.
#
#   make provision FLAVOR=otel SIZE=small NB_USERS=2
#
# flavor and instance_name MUST stay "otel": they select the image tag, the
# Ansible group_vars and the inventory file, and they tag the reserved IP. A
# different value here would boot a stranger, not a smaller version of the
# session server.
flavor        = "otel"
instance_name = "otel"

# GP1-S (8 vCPU / 32 GiB, 0.191 EUR/h) holds two stacks with room to spare:
# 2 x 8.5 GiB + ~6 GiB of base system = 23 GiB. Three stacks (31.5 GiB) is the
# ceiling and leaves nothing for the lab 2 build peak — go to GP1-M above that.
instance_type = "GP1-S"

# 2 x 21 GB of kind stores + ~23 GB of system and shared images = ~65 GB.
root_volume_size_gb = 100

# Same name as the session server, deliberately: only one of the two exists at
# a time (single OpenTofu state, single reserved IP), so the rehearsal happens
# on the very URL the participants will use — HTTPS included, which is what
# makes the Guacamole clipboard work.
dns_zone      = "k8s-school.fr"
dns_subdomain = "training"

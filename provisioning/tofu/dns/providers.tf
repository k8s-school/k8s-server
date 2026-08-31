terraform {
  required_version = ">= 1.6" # OpenTofu

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.0"
    }
  }
}

# A root module of its own, separate from the VM one, for two reasons.
#
# The technical one: the OVH provider validates its credentials against the API
# as soon as it is configured, and OpenTofu configures a provider whenever one
# of its resources appears in the configuration — `count = 0` does not help.
# Kept next to the instance, it would make OVH credentials mandatory even for a
# flavor that has no domain name.
#
# The one that matters: the record points at a reserved IP carrying
# prevent_destroy, which outlives every `make down`. So it is written once and
# left alone, while the VM state is torn down and rebuilt at each session —
# genuinely two different lifecycles.
#
# Credentials come from the environment, like the Scaleway ones:
# OVH_APPLICATION_KEY, OVH_APPLICATION_SECRET, OVH_CONSUMER_KEY — created once at
# https://api.ovh.com/createToken/ with GET/POST/PUT/DELETE on /domain/zone/*.
# The endpoint is a variable rather than OVH_ENDPOINT, so three environment
# variables are enough.
provider "ovh" {
  endpoint = var.ovh_endpoint
}

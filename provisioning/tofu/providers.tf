terraform {
  required_version = ">= 1.6" # OpenTofu

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Credentials, zone and region come from the environment / scw profile, same as
# the scw CLI: SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_PROJECT_ID,
# SCW_DEFAULT_ZONE, SCW_DEFAULT_REGION (or ~/.config/scw/config.yaml).
# Resources still pin their own zone via var.zone, so this stays deterministic.
# Leaving the block empty avoids the "multiple variable sources" warning when a
# scw profile is also present.
provider "scaleway" {}

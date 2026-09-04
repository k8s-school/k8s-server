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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Credentials, zone and region come from the environment / scw profile, exactly
# like the training-server state next door: SCW_ACCESS_KEY, SCW_SECRET_KEY,
# SCW_DEFAULT_PROJECT_ID (or ~/.config/scw/config.yaml). Resources pin their own
# zone through var.zone, so this stays deterministic.
provider "scaleway" {}

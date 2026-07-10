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

# Credentials come from the environment, same as the scw CLI:
#   SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_PROJECT_ID, SCW_DEFAULT_ORGANIZATION_ID
provider "scaleway" {
  zone   = var.zone
  region = var.region
}

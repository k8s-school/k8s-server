variable "dns_zone" {
  description = "OVH-hosted DNS zone, e.g. \"k8s-school.fr\". Read from the flavor's tfvars by `make dns`."
  type        = string

  validation {
    condition     = length(var.dns_zone) > 0
    error_message = "dns_zone is required. Set it in tofu/envs/<flavor>.tfvars, or don't run `make dns` at all."
  }
}

variable "dns_subdomain" {
  description = "Record name inside dns_zone; the resulting FQDN is <dns_subdomain>.<dns_zone>."
  type        = string
  default     = "training"
}

variable "target_ip" {
  description = <<-EOT
    Address the record points at. Passed by `make dns` from the main state's
    public_ip output — the reserved IP, which survives `make down`, so this
    value does not change from one session to the next.
  EOT
  type        = string
}

variable "dns_ttl" {
  description = <<-EOT
    TTL of the A record, in seconds. Kept short: the reserved IP does not move,
    so nothing is gained by caching it for hours, and a low value avoids a stale
    answer during the first Let's Encrypt challenge.
  EOT
  type        = number
  default     = 300
}

variable "ovh_endpoint" {
  description = "OVH API endpoint. ovh-eu is the European one (api.ovh.com), which serves k8s-school.fr."
  type        = string
  default     = "ovh-eu"
}

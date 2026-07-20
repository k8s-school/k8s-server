variable "flavor" {
  description = "Training flavor (k8s | openshift | otel). Selects naming and defaults."
  type        = string
}

variable "zone" {
  type    = string
  default = "fr-par-1"
}

variable "region" {
  type    = string
  default = "fr-par"
}

variable "instance_name" {
  description = "Instance + IP tag name. Mirrors INSTANCE_NAME in infra/env.<flavor>.sh."
  type        = string
}

variable "instance_type" {
  description = "Scaleway commercial type, e.g. GP1-M. Bump with student count."
  type        = string
  default     = "GP1-M"
}

variable "image_id" {
  description = <<-EOT
    Baked image built by Packer (packer build -var flavor=<flavor>).
    Injected by `make up`, which resolves it from the image's `flavor=<flavor>`
    tag. Required: there is no fallback distro — a session must run on a baked
    image. Build one first with `make create-image FLAVOR=<flavor>`.
  EOT
  type        = string

  validation {
    condition     = length(var.image_id) > 0
    error_message = "image_id is required. Build the golden image first: make create-image FLAVOR=<flavor>."
  }
}

variable "root_volume_size_gb" {
  type    = number
  default = 100
}

variable "ssh_public_key_path" {
  description = "Public key injected for root; the operator's key by default."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

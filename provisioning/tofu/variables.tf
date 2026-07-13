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
    Normally left empty and injected by `make up`, which resolves it from the
    image's `flavor=<flavor>` tag. Set it only to pin a specific image by hand
    (tofu apply -var image_id=<id>). Empty boots the raw `fallback_image`
    instead (slower: Ansible installs everything at session time).
  EOT
  type        = string
  default     = ""
}

variable "fallback_image" {
  description = "Distro label used when image_id is empty (ubuntu_noble, fedora, ...)."
  type        = string
  default     = "ubuntu_noble"
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

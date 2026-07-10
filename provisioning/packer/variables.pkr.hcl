variable "flavor" {
  type        = string
  default     = "otel"
  description = "Training flavor to bake (k8s | openshift | otel)."
}

variable "zone" {
  type    = string
  default = "fr-par-1"
}

variable "source_image" {
  type        = string
  default     = "ubuntu_noble"
  description = "Base distro image label. Use 'fedora' for the openshift flavor."
}

variable "commercial_type" {
  type        = string
  default     = "GP1-M"
  description = "Build-time instance type (can be smaller than the session type)."
}

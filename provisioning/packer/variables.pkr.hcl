variable "flavor" {
  type        = string
  default     = "otel"
  description = "Training flavor to bake (k8s | cks | openshift | otel)."
}

variable "name" {
  type        = string
  default     = ""
  description = "Name of the image on Scaleway (name and tag). Empty = the flavor, see local.name."
}

variable "zone" {
  type    = string
  default = "fr-par-1"
}

variable "source_image" {
  type        = string
  default     = ""
  description = "Base distro image label. Empty = the flavor's distro (see local.source_image)."
}

# The flavor decides the distro: openshift runs crc on Fedora, the others run on
# Ubuntu. Resolved here rather than by the caller, so `make create-image` and the
# GHA workflow (which both pass only -var flavor=...) bake the right base. Before
# this, FLAVOR=openshift silently baked an Ubuntu image tagged flavor=openshift.
locals {
  # What the image is called on Scaleway, decoupled from what it contains so a
  # flavor can be baked under a name that does not give it away (make NAME=...).
  name         = var.name != "" ? var.name : var.flavor
  source_image = var.source_image != "" ? var.source_image : lookup({ openshift = "fedora_44" }, var.flavor, "ubuntu_noble")
}

variable "commercial_type" {
  type        = string
  default     = "GP1-M"
  description = "Build-time instance type (can be smaller than the session type)."
}

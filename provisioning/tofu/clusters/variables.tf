variable "cluster_count" {
  description = <<-EOT
    Number of two-node clusters to provision — one per participant. Injected by
    `make cluster nb=<N>`; there is no default on purpose, so that a bare
    `tofu apply` in this directory cannot silently boot the wrong number of VMs.
  EOT
  type        = number

  validation {
    condition     = var.cluster_count > 0 && floor(var.cluster_count) == var.cluster_count
    error_message = "cluster_count must be a positive integer — use `make cluster nb=<N>`."
  }
}

# The two variables below must match ansible/group_vars/all/vars.yml: the VM
# names are built from them, and the whole design rests on a VM being named
# after the account that will use it (student3 -> student3-1 / student3-2).
# That is what lets labs/0_kubeadm/env.sh derive the cluster from $USER, with
# nothing generated per participant and nothing to type.
variable "user_prefix" {
  description = "Account prefix on the training server. Must match user_prefix in ansible/group_vars/all/vars.yml."
  type        = string
  default     = "student"
}

variable "user_start" {
  description = "Index of the first participant. Must match user_start in ansible/group_vars/all/vars.yml."
  type        = number
  default     = 1
}

variable "master_type" {
  description = <<-EOT
    Commercial type of the control-plane node. DEV1-M (3 vCPU, 4 GiB) rather
    than the cheaper DEV1-S: the VMs have no swap, so a memory spike during
    `kubeadm init` or `cilium install` gets kube-apiserver OOM-killed — the kind
    of failure that stops a lab in its tracks. A cluster lives ~2h, which puts
    the whole difference at about 2 cents per participant.
  EOT
  type        = string
  default     = "DEV1-M"
}

variable "worker_type" {
  description = <<-EOT
    Commercial type of the worker node. DEV1-S (2 vCPU, 2 GiB) is enough: it
    carries kubelet, cilium-agent and the handful of demo pods of labs
    0_kubeadm and 3_policies. The lab that deliberately floods node capacity
    (4_computational_resources) runs on kind, not here.
  EOT
  type        = string
  default     = "DEV1-S"
}

variable "image" {
  description = <<-EOT
    Scaleway marketplace image label. A plain distribution image, NOT the
    Packer-baked training image: installing containerd and kubeadm by hand *is*
    the lab.
  EOT
  type        = string
  default     = "ubuntu_noble" # Ubuntu 24.04 LTS
}

variable "zone" {
  description = "Scaleway availability zone. DEV1-S/DEV1-M are available in fr-par-1, fr-par-2, nl-ams-1 and pl-waw-1."
  type        = string
  default     = "fr-par-1"
}

variable "root_volume_size_gb" {
  description = <<-EOT
    Root volume size. 20 GB is the DEV1-S maximum for local storage, and leaves
    plenty of room: the control-plane images plus Cilium weigh a few GB.
  EOT
  type        = number
  default     = 20
}

variable "ssh_user" {
  description = "Login the participants use on the nodes. 'ubuntu' is the default account of Scaleway's Ubuntu images."
  type        = string
  default     = "ubuntu"
}

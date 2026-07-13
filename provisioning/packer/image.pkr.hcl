packer {
  required_plugins {
    scaleway = {
      source  = "github.com/scaleway/scaleway"
      version = ">= 1.1.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

# Credentials from the environment (same vars as the scw CLI / OpenTofu):
#   SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_PROJECT_ID
source "scaleway" "training" {
  zone            = var.zone
  image           = var.source_image
  commercial_type = var.commercial_type
  ssh_username    = "root"
  # Timestamped so old images are easy to identify and prune.
  image_name = "k8s-training-${var.flavor}-{{timestamp}}"
  # Stable label used by `make up` to find THIS flavor's image (no more copying
  # image_id around). The timestamped name still lets you eyeball/prune old ones.
  tags = ["k8s-training", "flavor=${var.flavor}"]
}

build {
  name    = "training-image"
  sources = ["source.scaleway.training"]

  # Bake only the STATIC layer: docker + base tooling. The per-session dynamic
  # bits (participants, repo clones, clusters) stay out of the image and run
  # later via ansible/site.yml.
  provisioner "ansible" {
    playbook_file = "../ansible/image.yml"
    # Without this the plugin defaults ansible_user to the *local* user running
    # packer (e.g. fjammes); the connection is actually root, so Ansible's
    # remote_tmp resolves to a literal `~fjammes` dir baked under /root. Pin it.
    user = "root"
    extra_arguments = [
      "-e", "flavor=${var.flavor}",
      "--scp-extra-args", "'-O'", # OpenSSH 9+ compatibility
    ]
  }

  # Emit the built image ID for the tofu tfvars.
  post-processor "manifest" {
    output = "manifest-${var.flavor}.json"
  }
}

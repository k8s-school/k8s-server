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
}

build {
  name    = "training-image"
  sources = ["source.scaleway.training"]

  # Bake only the STATIC layer: docker + base tooling. The per-session dynamic
  # bits (participants, repo clones, clusters) stay out of the image and run
  # later via ansible/site.yml.
  provisioner "ansible" {
    playbook_file = "../ansible/image.yml"
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

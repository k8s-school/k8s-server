# Thin wrapper around OpenTofu + Ansible. Pick the flavor on the command line:
#   make up FLAVOR=otel
# Run `make` (or `make help`) to list the available targets.
FLAVOR ?= otel
ZONE ?= fr-par-1
TOFU_DIR := tofu
ANSIBLE_DIR := ansible
TFVARS := envs/$(FLAVOR).tfvars
INVENTORY := $(ANSIBLE_DIR)/inventory/$(FLAVOR).ini

# Shell pipeline printing the Scaleway image IDs tagged for the current FLAVOR
# (one per line). This is how the image is found by tag instead of a pinned id.
IMAGE_IDS = scw instance image list zone=$(ZONE) -o json | jq -r --arg t "flavor=$(FLAVOR)" '.[] | select((.tags // []) | index($$t)) | .id'

.DEFAULT_GOAL := help
.PHONY: help init create-image up down configure provision ssh ip fmt validate delete-image delete-ip

help: ## Show this help (default target)
	@echo "Training provisioning — usage: make <target> [FLAVOR=k8s|openshift|otel]"
	@echo "Current FLAVOR=$(FLAVOR)"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

init: ## One-time: initialize the OpenTofu working directory
	cd $(TOFU_DIR) && tofu init

create-image: ## Build the golden Scaleway image with Packer (locally)
	cd packer && packer init . && packer build -var flavor=$(FLAVOR) .
	@# Packer prints "An image was created" twice (harmless manifest quirk). The
	@# image is found by its 'flavor=$(FLAVOR)' tag, so nothing to copy anywhere.
	@ids=$$($(IMAGE_IDS)); n=$$(printf '%s\n' "$$ids" | grep -c .); \
	echo ""; \
	if [ "$$n" -gt 1 ]; then \
	  echo "WARNING: $$n images now carry the tag 'flavor=$(FLAVOR)':"; \
	  printf '  %s\n' $$ids; \
	  echo "'make up FLAVOR=$(FLAVOR)' will REFUSE to run until exactly one remains."; \
	  echo "Prune the stale one(s): make delete-image FLAVOR=$(FLAVOR)  (deletes ALL of them)"; \
	  echo "                    or: scw instance image delete <id> with-snapshots=true"; \
	else \
	  echo "Image built and tagged 'flavor=$(FLAVOR)' (id: $$ids)."; \
	  echo "Nothing to copy: 'make up FLAVOR=$(FLAVOR)' resolves it by tag automatically."; \
	fi

up: ## Create/update the VM + reserved IP, and write the Ansible inventory
	@ids=$$($(IMAGE_IDS)); n=$$(printf '%s\n' "$$ids" | grep -c .); \
	if [ "$$n" -gt 1 ]; then \
	  echo "ERROR: $$n images are tagged 'flavor=$(FLAVOR)' — cannot pick one:"; \
	  printf '  %s\n' $$ids; \
	  echo "Keep a single image for this flavor, then retry. Prune with:"; \
	  echo "  make delete-image FLAVOR=$(FLAVOR)   (deletes ALL, then rebuild one)"; \
	  echo "  scw instance image delete <id> with-snapshots=true   (targeted)"; \
	  exit 1; \
	elif [ "$$n" -eq 1 ]; then \
	  echo "Using baked image $$ids (tag flavor=$(FLAVOR))."; \
	  cd $(TOFU_DIR) && tofu apply -var-file=$(TFVARS) -var image_id="$$ids" -auto-approve; \
	else \
	  echo "No image tagged 'flavor=$(FLAVOR)'; booting the raw distro (fallback_image)."; \
	  echo "Build one first for a faster session: make create-image FLAVOR=$(FLAVOR)"; \
	  cd $(TOFU_DIR) && tofu apply -var-file=$(TFVARS) -auto-approve; \
	fi

configure: ## Run Ansible: participant accounts, repo clones, training clusters
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/$(FLAVOR).ini site.yml -e flavor=$(FLAVOR)

provision: up configure ## Full session bring-up (up + configure)

down: ## Destroy the VM (keeps the reserved IP)
	cd $(TOFU_DIR) && tofu destroy -var-file=$(TFVARS) -auto-approve

delete-image: ## Delete every Scaleway image (+ snapshot) tagged flavor=<FLAVOR>
	@ids=$$($(IMAGE_IDS)); \
	if [ -z "$$ids" ]; then echo "No image tagged 'flavor=$(FLAVOR)', nothing to delete"; exit 0; fi; \
	for img in $$ids; do \
	  echo "Deleting Scaleway image $$img (with snapshot)"; \
	  scw instance image delete "$$img" with-snapshots=true; \
	done

delete-ip: ## Release the reserved (floating) IP for this flavor
	@name=$$(grep -E '^[[:space:]]*instance_name' $(TOFU_DIR)/$(TFVARS) | sed -E 's/.*"([^"]+)".*/\1/'); \
	if [ -z "$$name" ]; then echo "No instance_name in $(TFVARS)"; exit 1; fi; \
	ip_id=$$(scw instance ip list tags.0="$$name" | grep -w "$$name" | awk '{print $$1}'); \
	if [ -z "$$ip_id" ]; then echo "No reserved IP tagged $$name, nothing to delete"; exit 0; fi; \
	echo "Deleting reserved IP $$ip_id (tag $$name)"; \
	scw instance ip delete "$$ip_id"

ip: ## Print the instance public IP
	cd $(TOFU_DIR) && tofu output -raw public_ip

ssh: ## SSH to the instructor account (k8s0)
	ssh k8s0@$$(cd $(TOFU_DIR) && tofu output -raw public_ip)

fmt: ## Format the OpenTofu and Packer files
	cd $(TOFU_DIR) && tofu fmt
	cd packer && packer fmt .

validate: ## Validate the OpenTofu configuration
	cd $(TOFU_DIR) && tofu validate

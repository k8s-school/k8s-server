# Thin wrapper around OpenTofu + Ansible. Pick the flavor on the command line:
#   make up FLAVOR=otel
#   make configure FLAVOR=otel
FLAVOR ?= otel
TOFU_DIR := tofu
ANSIBLE_DIR := ansible
TFVARS := envs/$(FLAVOR).tfvars
INVENTORY := $(ANSIBLE_DIR)/inventory/$(FLAVOR).ini

.PHONY: init up down configure provision ssh ip fmt validate delete-image

init:
	cd $(TOFU_DIR) && tofu init

# Create/patch the VM and reserved IP. Writes the ansible inventory as a side
# effect (see tofu/main.tf local_file.inventory).
up:
	cd $(TOFU_DIR) && tofu apply -var-file=$(TFVARS) -auto-approve

down:
	cd $(TOFU_DIR) && tofu destroy -var-file=$(TFVARS) -auto-approve

# Per-session configuration: participant accounts, repo clones, clusters.
configure:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/$(FLAVOR).ini site.yml -e flavor=$(FLAVOR)

# Full session bring-up.
provision: up configure

# Delete the Scaleway image + its snapshot referenced in the flavor tfvars, to
# stop paying image storage between sessions (rebuild before the next one).
# Leaves image_id in the tfvars; the next `make image` / GHA build overwrites it.
delete-image:
	@img=$$(grep -E '^[[:space:]]*image_id' $(TOFU_DIR)/$(TFVARS) | sed -E 's/.*"([^"]+)".*/\1/'); \
	if [ -z "$$img" ]; then echo "No image_id set in $(TFVARS), nothing to delete"; exit 0; fi; \
	echo "Deleting Scaleway image $$img (with snapshot)"; \
	scw instance image delete "$$img" with-snapshots=true

ip:
	cd $(TOFU_DIR) && tofu output -raw public_ip

ssh:
	ssh k8s0@$$(cd $(TOFU_DIR) && tofu output -raw public_ip)

fmt:
	cd $(TOFU_DIR) && tofu fmt
	cd packer && packer fmt .

validate:
	cd $(TOFU_DIR) && tofu validate

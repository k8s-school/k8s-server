# Thin wrapper around OpenTofu + Ansible. Pick the flavor on the command line:
#   make up FLAVOR=otel
# Run `make` (or `make help`) to list the available targets.
FLAVOR ?= otel
TOFU_DIR := tofu
ANSIBLE_DIR := ansible
TFVARS := envs/$(FLAVOR).tfvars
INVENTORY := $(ANSIBLE_DIR)/inventory/$(FLAVOR).ini

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
	@echo "Put the printed image ID into $(TOFU_DIR)/$(TFVARS) (image_id), or let the GHA workflow do it."

up: ## Create/update the VM + reserved IP, and write the Ansible inventory
	cd $(TOFU_DIR) && tofu apply -var-file=$(TFVARS) -auto-approve

configure: ## Run Ansible: participant accounts, repo clones, training clusters
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/$(FLAVOR).ini site.yml -e flavor=$(FLAVOR)

provision: up configure ## Full session bring-up (up + configure)

down: ## Destroy the VM (keeps the reserved IP)
	cd $(TOFU_DIR) && tofu destroy -var-file=$(TFVARS) -auto-approve

delete-image: ## Delete the Scaleway image + snapshot referenced in the tfvars
	@img=$$(grep -E '^[[:space:]]*image_id' $(TOFU_DIR)/$(TFVARS) | sed -E 's/.*"([^"]+)".*/\1/'); \
	if [ -z "$$img" ]; then echo "No image_id set in $(TFVARS), nothing to delete"; exit 0; fi; \
	echo "Deleting Scaleway image $$img (with snapshot)"; \
	scw instance image delete "$$img" with-snapshots=true

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

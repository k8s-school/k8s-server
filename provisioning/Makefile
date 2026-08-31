# Thin wrapper around OpenTofu + Ansible. Pick the flavor on the command line:
#   make up FLAVOR=otel
# Run `make` (or `make help`) to list the available targets.
FLAVOR ?= otel
ZONE ?= fr-par-1
SSH_USER ?= root
TOFU_DIR := tofu
DNS_DIR := tofu/dns
ANSIBLE_DIR := ansible
TFVARS := envs/$(FLAVOR).tfvars
INVENTORY := $(ANSIBLE_DIR)/inventory/$(FLAVOR).ini

# Pull a quoted value out of the flavor's tfvars, e.g. $(call tfvar,dns_zone).
# The DNS state is applied separately (see the `dns` target), so it gets its
# inputs this way instead of reading the file itself — its variables are not the
# same set as the VM state's.
tfvar = $$(grep -E '^[[:space:]]*$(1)[[:space:]]*=' $(TOFU_DIR)/$(TFVARS) | sed -E 's/.*"([^"]+)".*/\1/')

# Shell pipeline printing the Scaleway image IDs tagged for the current FLAVOR
# (one per line). This is how the image is found by tag instead of a pinned id.
IMAGE_IDS = scw instance image list zone=$(ZONE) -o json | jq -r --arg t "flavor=$(FLAVOR)" '.[] | select((.tags // []) | index($$t)) | .id'

.DEFAULT_GOAL := help
.PHONY: help init create-image up dns down configure provision ssh ip fqdn fmt validate delete-image delete-ip delete-dns

help: ## Show this help (default target)
	@echo "Training provisioning — usage: make <target> [FLAVOR=k8s|openshift|otel]"
	@echo "Current FLAVOR=$(FLAVOR)"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

init: ## One-time: initialize the OpenTofu working directories (VM + DNS)
	cd $(TOFU_DIR) && tofu init
	cd $(DNS_DIR) && tofu init

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
	  echo "ERROR: no image tagged 'flavor=$(FLAVOR)' — nothing to boot."; \
	  echo "There is no fallback distro. Build the golden image first:"; \
	  echo "  make create-image FLAVOR=$(FLAVOR)"; \
	  exit 1; \
	fi

dns: ## Point the flavor's DNS record at the reserved IP (no-op without dns_zone)
	@# Separate OpenTofu state (tofu/dns): the OVH provider checks its credentials
	@# as soon as it is configured, so keeping it out of the VM state is what lets
	@# a flavor with no domain name run without any OVH credentials at all.
	@# Needs OVH_APPLICATION_KEY / OVH_APPLICATION_SECRET / OVH_CONSUMER_KEY.
	@zone="$(call tfvar,dns_zone)"; sub="$(call tfvar,dns_subdomain)"; \
	if [ -z "$$zone" ]; then \
	  echo "No dns_zone in $(TFVARS): $(FLAVOR) has no public name, nothing to do."; \
	  echo "(Guacamole is then served over plain HTTP — see provisioning/README.md.)"; \
	  exit 0; \
	fi; \
	ip=$$(cd $(TOFU_DIR) && tofu output -raw public_ip) || \
	  { echo "ERROR: no public_ip in the VM state — run 'make up FLAVOR=$(FLAVOR)' first."; exit 1; }; \
	echo "Pointing $${sub:-training}.$$zone at $$ip"; \
	cd $(DNS_DIR) && tofu init -input=false >/dev/null && \
	tofu apply -var dns_zone="$$zone" -var dns_subdomain="$${sub:-training}" -var target_ip="$$ip" -auto-approve

configure: ## Run Ansible: participant accounts, repo clones, training clusters
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/$(FLAVOR).ini site.yml -e flavor=$(FLAVOR)

provision: up dns configure ## Full session bring-up (up + dns + configure)

down: ## Destroy the VM only (keeps the reserved IP for the next session)
	@# A blanket `tofu destroy` would try to delete the IP too, which has
	@# prevent_destroy set. Target the server so the IP (and its state) survive;
	@# null_resource.wait_for_ssh is torn down with it as a dependent.
	@# image_id is a required var but irrelevant to a targeted destroy — pass a
	@# placeholder just to satisfy it.
	cd $(TOFU_DIR) && tofu destroy -target=scaleway_instance_server.main -var-file=$(TFVARS) -var image_id=unused-on-destroy -auto-approve

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

delete-dns: ## Remove the DNS record for this flavor (the reserved IP is untouched)
	@zone="$(call tfvar,dns_zone)"; \
	if [ -z "$$zone" ]; then echo "No dns_zone in $(TFVARS), nothing to delete"; exit 0; fi; \
	cd $(DNS_DIR) && tofu destroy -auto-approve \
	  -var dns_zone="$$zone" -var dns_subdomain="$(call tfvar,dns_subdomain)" -var target_ip=unused-on-destroy

ip: ## Print the instance public IP
	cd $(TOFU_DIR) && tofu output -raw public_ip

fqdn: ## Print the public name of the instance (empty when no dns_zone)
	@cd $(TOFU_DIR) && tofu output -raw fqdn

ssh: ## SSH to the VM as root (admin access via the operator key). Override user: make ssh SSH_USER=student1
	ssh $(SSH_USER)@$$(cd $(TOFU_DIR) && tofu output -raw public_ip)

fmt: ## Format the OpenTofu and Packer files
	cd $(TOFU_DIR) && tofu fmt -recursive
	cd packer && packer fmt .

validate: ## Validate the OpenTofu configuration (VM + DNS)
	cd $(TOFU_DIR) && tofu validate
	cd $(DNS_DIR) && tofu validate

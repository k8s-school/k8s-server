# Thin wrapper around OpenTofu + Ansible. Pick the flavor on the command line:
#   make up FLAVOR=otel
# Run `make` (or `make help`) to list the available targets.
FLAVOR ?= otel
ZONE ?= fr-par-1
SSH_USER ?= root
TOFU_DIR := tofu
DNS_DIR := tofu/dns
CLUSTERS_DIR := tofu/clusters
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
.PHONY: help init create-image up dns down configure provision ssh ip fqdn fmt validate delete-image delete-ip delete-dns status \
        cluster cluster-dispatch cluster-list cluster-ssh cluster-down

help: ## Show this help (default target)
	@echo "Training provisioning — usage: make <target> [FLAVOR=k8s|openshift|otel]"
	@echo "Current FLAVOR=$(FLAVOR)"
	@echo "The cluster-* targets take nb=<N> instead, not FLAVOR — see README.md."
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

init: ## One-time: initialize the OpenTofu working directories (VM + DNS + clusters)
	cd $(TOFU_DIR) && tofu init
	cd $(DNS_DIR) && tofu init
	cd $(CLUSTERS_DIR) && tofu init

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

# ---------------------------------------------------------------------------
# Lab clusters (labs/0_kubeadm) — two VMs per participant, own OpenTofu state.
#
# These are driven by nb=<N>, not by FLAVOR: they are the same for every
# flavor, and their lifetime is the lab's (about two hours), not the session's.
# Hence the separate state in tofu/clusters — one `destroy` must never
# endanger the other.
# ---------------------------------------------------------------------------

# nb= is the participant count. Refuse anything that is not a positive integer
# here rather than letting `tofu apply` fail halfway: this is the one command a
# trainer types under time pressure at the start of a lab.
define require_nb
	case "$(nb)" in \
	  '') echo "ERROR: nb=<N> is required, e.g. 'make $@ nb=10' for 10 participants."; exit 1 ;; \
	  *[!0-9]*) echo "ERROR: nb must be a positive integer, got '$(nb)'."; exit 1 ;; \
	  0) echo "ERROR: nb must be greater than 0."; exit 1 ;; \
	esac
endef

cluster: ## Boot nb=<N> two-node kubeadm clusters, one per participant
	@$(require_nb); \
	cd $(CLUSTERS_DIR) && tofu apply -var cluster_count=$(nb) -auto-approve
	@echo ""
	@cd $(CLUSTERS_DIR) && tofu output -raw summary
	@echo ""
	@echo "Next: make cluster-dispatch   (hands the access to the student<N> accounts)"

cluster-dispatch: ## Give each participant the ssh access to their own cluster
	@# Reads tofu/clusters/../../ansible/data/clusters.yml, written by `make cluster`.
	@# Runs against the training server, so it uses that flavor's inventory.
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/$(FLAVOR).ini lab-clusters.yml -e flavor=$(FLAVOR)

cluster-list: ## Print the participant-to-address table
	@cd $(CLUSTERS_DIR) && tofu output -raw summary
	@echo ""

cluster-ssh: ## SSH to a lab node as the trainer: make cluster-ssh node=student3-1
	@if [ -z "$(node)" ]; then \
	  echo "ERROR: node=<name> is required, e.g. 'make cluster-ssh node=student3-1'."; exit 1; \
	fi; \
	ip=$$(cd $(CLUSTERS_DIR) && tofu output -json node_ips | jq -r --arg n "$(node)" '.[$$n] // empty'); \
	if [ -z "$$ip" ]; then \
	  echo "ERROR: no node named '$(node)' in the state. Known nodes:"; \
	  (cd $(CLUSTERS_DIR) && tofu output -json node_ips | jq -r 'keys[]' | sed 's/^/  /'); \
	  exit 1; \
	fi; \
	ssh ubuntu@"$$ip"

cluster-down: ## Destroy every lab cluster (VMs AND their IPs)
	@# cluster_count is a required variable but irrelevant to a destroy, which
	@# works off the state and not the configuration — pass a placeholder just to
	@# satisfy it, the same way `down` passes image_id=unused-on-destroy.
	@# Unlike the training server's reserved IP, nothing here carries
	@# prevent_destroy: a lab IP that outlives its VM is billed for nothing.
	cd $(CLUSTERS_DIR) && tofu destroy -var cluster_count=1 -auto-approve
	@echo ""
	@echo "Check nothing is left behind:"
	@echo "  scw instance server list tags.0=kubeadm-lab"
	@echo "  scw instance ip list tags.0=kubeadm-lab"


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

status: ## Show what exists right now on the account (i.e. what is billed) + DNS
	@# Read from the provider, not from the OpenTofu state: the point is to spot
	@# everything still alive after a session, including what the state does not
	@# know about — an image from a past build, a volume left behind by a deleted
	@# server, a snapshot. Those keep billing while nothing runs.
	@command -v scw >/dev/null || { echo "scw CLI not found (see install-tools.sh)"; exit 1; }
	@echo "== Instances (zone $(ZONE)) =="
	@scw instance server list zone=$(ZONE) -o json | jq -r \
	  'if length == 0 then "  (none)" else .[] | "  \(.name)  [\(.state)]  \(.commercial_type)  \(.public_ip.address // "no ip")  tags=[\(.tags | join(","))]" end'
	@echo
	@echo "== Reserved IPs (billed even while detached) =="
	@scw instance ip list zone=$(ZONE) -o json | jq -r \
	  'if length == 0 then "  (none)" else .[] | "  \(.address)  \(if .server then "attached to \(.server.name)" else "DETACHED" end)  tags=[\(.tags | join(","))]" end'
	@echo
	@echo "== Images (flavor-tagged ones are what 'make up' boots) =="
	@scw instance image list zone=$(ZONE) -o json | jq -r \
	  'if length == 0 then "  (none)" else .[] | "  \(.name)  tags=[\(.tags | join(","))]  \(.creation_date[0:10])  id=\(.id)" end'
	@echo
	@echo "== Block volumes attached to nothing (billed all the same) =="
	@# Two known sources: a `make down` leaves the server's root volume behind, and
	@# Packer used to leak one per build (fixed by remove_volume in image.pkr.hcl —
	@# a leftover named after the source image means a build predating it). Grouped
	@# by name+size with the date span, else one line each buries the report.
	@# Delete them by id: scw block volume list zone=$(ZONE) / scw block volume delete <id>
	@scw block volume list zone=$(ZONE) -o json | jq -r '[.[] | select((.references // []) | length == 0)] | if length == 0 then "  (none)" else (group_by(.name, .size)[] | "  \(length)x  \(.[0].name)  \(.[0].size / 1000000000 | floor) GB each  (\(min_by(.created_at).created_at[0:10]) -> \(max_by(.created_at).created_at[0:10]))"), "  -> \(map(.size) | add / 1000000000 | floor) GB in \(length) unattached volume(s)" end'
	@echo
	@echo "== Block snapshots (billed; an image IS a snapshot, hence the cross-check) =="
	@# A snapshot listed as backing an image is not waste — it is the image `make
	@# up` boots. Only the orphans are: `scw instance image delete` without
	@# with-snapshots=true leaves one behind every time.
	@imgs=$$(scw instance image list zone=$(ZONE) -o json | jq -c '[.[] | {id: .root_volume.id, name: .name}]'); \
	scw block snapshot list zone=$(ZONE) -o json | jq -r --argjson imgs "$$imgs" 'if length == 0 then "  (none)" else (.[] | . as $$s | ($$imgs | map(select(.id == $$s.id)) | first) as $$img | "  \(.name)  \(.size / 1000000000 | floor) GB  \(if $$img then "backs image \($$img.name)" else "ORPHAN  id=\(.id)" end)"), ([.[] | select(.id as $$i | ($$imgs | map(.id) | index($$i)) | not)] | "  -> \(map(.size) | add // 0 | . / 1000000000 | floor) GB in \(length) orphan snapshot(s)") end'
	@echo
	@echo "== OpenTofu state =="
	@# One state, one workspace: it holds whichever flavor `make up` last applied,
	@# not necessarily FLAVOR=$(FLAVOR) — the server name below says which.
	@if [ ! -f $(TOFU_DIR)/terraform.tfstate ]; then echo "  vm: no state yet (never ran 'make up')"; else \
	  name=$$(jq -r '.resources[] | select(.type == "scaleway_instance_server") | .instances[0].attributes.name' $(TOFU_DIR)/terraform.tfstate); \
	  ip=$$(cd $(TOFU_DIR) && tofu output -raw public_ip 2>/dev/null); \
	  if [ -n "$$name" ]; then echo "  vm: $$name present at $$ip"; \
	  else echo "  vm: destroyed, reserved ip kept ($$ip)"; fi; fi
	@zone="$(call tfvar,dns_zone)"; \
	if [ -z "$$zone" ]; then echo "  dns: no dns_zone in $(TFVARS) — $(FLAVOR) is served over plain HTTP"; \
	elif [ ! -f $(DNS_DIR)/terraform.tfstate ]; then echo "  dns: $(call tfvar,dns_subdomain).$$zone declared in $(TFVARS) but never applied — run 'make dns'"; \
	else echo "  dns: $$(cd $(DNS_DIR) && tofu output -raw fqdn 2>/dev/null) -> $$(cd $(DNS_DIR) && tofu output -raw target_ip 2>/dev/null)"; fi

ip: ## Print the instance public IP
	cd $(TOFU_DIR) && tofu output -raw public_ip

fqdn: ## Print the public name of the instance (empty when no dns_zone)
	@cd $(TOFU_DIR) && tofu output -raw fqdn

ssh: ## SSH to the VM as root (admin access via the operator key). Override user: make ssh SSH_USER=student1
	ssh $(SSH_USER)@$$(cd $(TOFU_DIR) && tofu output -raw public_ip)

fmt: ## Format the OpenTofu and Packer files
	cd $(TOFU_DIR) && tofu fmt -recursive
	cd packer && packer fmt .

validate: ## Validate the OpenTofu configuration (VM + DNS + clusters)
	cd $(TOFU_DIR) && tofu validate
	cd $(DNS_DIR) && tofu validate
	cd $(CLUSTERS_DIR) && tofu validate

# Training environment provisioning (OpenTofu + Packer + Ansible)

Replacement for the imperative `infra/start.sh` + `bootstrap/*` bash flow.
Splits the work along its natural seam:

| Layer      | Tool     | Changes...            | What it does                                            |
|------------|----------|-----------------------|---------------------------------------------------------|
| Image      | Packer   | rarely (new tooling)  | Bakes a golden Scaleway image: docker, go, kind, kubectl, helm, ktbx |
| Infra      | OpenTofu | every session         | Boots one VM from the baked image, reuses the tagged IP |
| Config     | Ansible  | every session         | Participant accounts, repo clones, per-user cluster env |

The three flavors (`k8s`, `openshift`, `otel`) are selected with a single
variable, mirroring `infra/conf.sh`.

## One-time: bake the image

```bash
cd packer
export SCW_DEFAULT_PROJECT_ID=... SCW_ACCESS_KEY=... SCW_SECRET_KEY=...
packer init .
packer build -var flavor=otel .
# -> prints the built image ID; put it in tofu/envs/<flavor>.tfvars (image_id)
```

Re-bake only when the static tooling changes (new docker/kind/helm version).

## Each session: boot + configure

```bash
make up FLAVOR=otel      # tofu apply + writes the ansible inventory
make configure FLAVOR=otel   # ansible-playbook site.yml (users, repos, clusters)
make ssh FLAVOR=otel     # ssh to the instructor account
make down FLAVOR=otel     # tofu destroy (keeps the reserved IP)
```

## Layout

```
provisioning/
├── Makefile              # thin wrapper around the 3 tools
├── packer/               # golden image build (runs ansible/image.yml)
├── tofu/                 # VM + IP lifecycle, one *.tfvars per flavor
└── ansible/
    ├── image.yml         # play baked INTO the image (docker + base_tools)
    ├── site.yml          # play run per-session (participants + training)
    ├── group_vars/       # per-flavor knobs (prefix, repo, cluster policy)
    └── roles/
        ├── docker/       # docker-ce, socket-activated (baked)
        ├── base_tools/   # go, kind, kubectl, helm, ktbx (baked)
        ├── participants/ # accounts, home, repo clone, bashrc (per-session)
        └── training/     # ktbx create / helm / crc (per-session)
```

> Skeleton: search for `TODO` before first real use (credentials, image IDs,
> pinned versions). The Ansible roles intentionally reproduce the logic of the
> current `bootstrap/*` scripts, but idempotently.

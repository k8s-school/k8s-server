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

## Usage

Everything goes through `make`. Run it with no argument for the authoritative,
self-documenting list of targets:

```bash
make                    # or: make help
```

Pick the flavor with `FLAVOR=` (`k8s` | `openshift` | `otel`, default `otel`).
Scaleway credentials come from the environment, like the `scw` CLI:

```bash
export SCW_ACCESS_KEY=... SCW_SECRET_KEY=... SCW_DEFAULT_PROJECT_ID=...
```

Typical lifecycle:

1. **Once** (or when the tooling changes): `make create-image` bakes the golden
   image and prints its ID → set it as `image_id` in `tofu/envs/<flavor>.tfvars`
   (the GHA workflow can do this via an auto-PR).
2. **Each session**: `make provision` (boots the VM + configures accounts), then
   `make ssh`.
3. **Teardown**: `make down`, then `make delete-image` / `make delete-ip` to stop
   paying for anything between sessions.

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
        ├── trainer/      # shared trainer account: sudo + docker + repo (per-session)
        ├── training/     # ktbx create / helm / crc (per-session)
        └── guacamole/    # optional browser SSH gateway, Docker stack (per-session)
```

## Optional: Guacamole browser SSH gateway

[Apache Guacamole](https://guacamole.apache.org/) gives participants a
browser-based terminal (no SSH client needed) — one auto-generated SSH
connection per account, straight to their own training user. It runs as a Docker
stack (`postgres` + `guacd` + `guacamole`) on the server, provisioned per session
by the `guacamole` role.

Off by default. Enable it per flavor in `ansible/group_vars/<flavor>.yml`:

```yaml
guacamole_enabled: true
```

then `make configure FLAVOR=<flavor>` (or `make provision`). Access it at
`http://<server>/guacamole`:

- **Participants** log in with their training username/password (`student<N>` /
  `k8s<N>`) and see a single "SSH `<user>`" connection to their own account.
- **Admin** is `guacadmin`, password = the vaulted trainer password.

The role also enables sshd `PasswordAuthentication` (Guacamole logs users in over
SSH) and publishes the web UI on port 80 — the training tooling already holds
8080. Tunables (version, port, images, password embedding) live in
`roles/guacamole/defaults/main.yml`.

> Skeleton: search for `TODO` before first real use (credentials, image IDs,
> pinned versions). The Ansible roles intentionally reproduce the logic of the
> current `bootstrap/*` scripts, but idempotently.

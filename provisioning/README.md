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

`make dns` (see below) additionally needs OVH API credentials, created once at
<https://api.ovh.com/createToken/> with `GET`/`POST`/`PUT`/`DELETE` on
`/domain/zone/*`:

```bash
export OVH_APPLICATION_KEY=... OVH_APPLICATION_SECRET=... OVH_CONSUMER_KEY=...
```

They are used a handful of times a year, so the operator machine keeps them in a
mode-600 file (`~/.config/ovh/k8s-school.env`, holding the three lines above)
and sources it right before the call rather than exporting them in a shell
profile:

```bash
set -a; . ~/.config/ovh/k8s-school.env; set +a && make dns FLAVOR=otel
```

Nothing else needs them: the DNS record lives in its own OpenTofu state
(`tofu/dns/`), so a flavor without a domain name never touches the OVH provider.

Typical lifecycle:

1. **Once** (or when the tooling changes): `make create-image` bakes the golden
   image and prints its ID → set it as `image_id` in `tofu/envs/<flavor>.tfvars`
   (the GHA workflow can do this via an auto-PR).
2. **Each session**: `make provision` (boots the VM + configures accounts), then
   `make ssh`.
3. **Teardown**: `make down`, then `make delete-image` / `make delete-ip` to stop
   paying for anything between sessions. `make status` lists what is still
   alive on the account — instances, reserved IPs, images, and the volumes and
   snapshots a deleted server leaves behind, which keep billing on their own.

## Lab kubeadm: one cluster per participant

`labs/0_kubeadm` of [k8s-advanced](https://github.com/k8s-school/k8s-advanced)
is the only lab of the course that cannot run on kind: building a control plane
by hand needs real machines. `make cluster` boots **two VMs per participant** —
`student<I>-1` (master) and `student<I>-2` (worker):

```bash
make cluster nb=10        # 10 participants -> 20 VMs, ~1 min
make cluster-dispatch     # drops the ssh access into the student<N> accounts
# ... the lab runs ...
make cluster-down         # destroys the VMs AND their IPs
```

Participants then just type `ssh student3-1` from their training terminal:
`make cluster-dispatch` wrote the key and the `~/.ssh/config` entries into their
account, and `labs/0_kubeadm/env.sh` derives `MASTER`/`NODES` from `$USER`, so
there is nothing to configure and nothing to type. That naming is the whole
point of the design — VM names match the account names created by the
`participants` role, and Scaleway takes the hostname from the VM name, so the
Kubernetes node names read the same as the SSH host names.

`make cluster-dispatch` needs the accounts to exist, so run it after
`make configure`; it fails with an explicit message otherwise.

Sizing, and what it costs (`fr-par-1` prices):

| Node | Type | Specs | Why |
|---|---|---|---|
| `student<I>-1` master | `DEV1-M` | 3 vCPU, 4 GiB, 0.020 €/h | The VMs have no swap, so a memory spike during `kubeadm init` or `cilium install` gets `kube-apiserver` OOM-killed. Not worth saving 1 cent. |
| `student<I>-2` worker | `DEV1-S` | 2 vCPU, 2 GiB, 0.009 €/h | Only carries kubelet, cilium-agent and a handful of demo pods. |

A cluster therefore costs **0.029 €/h**, so about **6 cents per participant** for
a two-hour lab. The VMs boot from a plain `ubuntu_noble` image, *not* the
Packer-baked one: installing containerd and kubeadm is the exercise.

Its own OpenTofu state (`tofu/clusters/`), for the reason that matters:
lifetime. The training server lives for the whole session behind a reserved IP
carrying `prevent_destroy`; these clusters are booted for a two-hour lab and
destroyed right after. Nothing here carries `prevent_destroy` — a lab IP that
outlives its VM is billed for nothing, which is the classic way a training
session quietly costs money for weeks. Everything is tagged `kubeadm-lab`, so a
leftover is one command away:

```bash
scw instance server list tags.0=kubeadm-lab
scw instance ip list tags.0=kubeadm-lab
```

## Layout

```
provisioning/
├── Makefile              # thin wrapper around the 3 tools
├── packer/               # golden image build (runs ansible/image.yml)
├── tofu/                 # VM + IP lifecycle, one *.tfvars per flavor
│   ├── dns/              # OVH DNS record, separate state (see below)
│   └── clusters/         # kubeadm lab clusters, separate state (see below)
└── ansible/
    ├── image.yml         # play baked INTO the image (docker + base_tools)
    ├── site.yml          # play run per-session (participants + training)
    ├── lab-clusters.yml  # play run per-lab (kubeadm cluster access)
    ├── group_vars/       # per-flavor knobs (prefix, repo, cluster policy)
    └── roles/
        ├── docker/       # docker-ce, socket-activated (baked)
        ├── base_tools/   # go, kind, kubectl, helm, ktbx (baked)
        ├── participants/ # accounts, home, repo clone, bashrc (per-session)
        ├── trainer/      # shared trainer account: sudo + docker + repo (per-session)
        ├── training/     # ktbx create / helm / crc (per-session)
        ├── lab_clusters/ # per-participant kubeadm cluster access (per-lab)
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
`https://training.k8s-school.fr/` (or `http://<server>/guacamole` on a flavor
with no DNS name — see below):

- **Participants** log in with their training username/password (`student<N>` /
  `k8s<N>`) and see a single "SSH `<user>`" connection to their own account.
- **Admin** is `guacadmin`, password = the vaulted trainer password.

The role also enables sshd `PasswordAuthentication` (Guacamole logs users in over
SSH) and publishes the web UI on port 80 — the training tooling already holds
8080. Tunables (version, port, images, password embedding) live in
`roles/guacamole/defaults/main.yml`.

### DNS and HTTPS

Set a `dns_zone` in the flavor's `tofu/envs/<flavor>.tfvars` and everything else
follows:

```hcl
dns_zone      = "k8s-school.fr"   # OVH-hosted zone
dns_subdomain = "training"        # -> training.k8s-school.fr
```

`make dns` then creates the A record pointing at the reserved IP (`make
provision` runs it between `up` and `configure`). The same two values make the
VM state write the resulting name into the generated Ansible inventory as
`guacamole_fqdn`, and the `guacamole` role turns on HTTPS because it received
one: a Caddy container is added in front of the stack, obtains a Let's Encrypt
certificate, renews it, and the web app moves to the root of the name
(`WEBAPP_CONTEXT: ROOT`) instead of being published on the host.

The record is a separate OpenTofu state on purpose. The OVH provider validates
its credentials as soon as it is configured, and OpenTofu configures a provider
as soon as one of its resources appears in the configuration — a `count = 0`
does not help — so keeping it in the VM state would make OVH credentials
mandatory for every flavor. It also matches reality: the record points at the
reserved IP, which survives `make down`, so it is written once and then left
alone while the VM is destroyed and rebuilt at each session.

The point is not the padlock: Chrome and Firefox restrict the async Clipboard
API to secure contexts, so **copy-paste between the student's machine and the
remote desktop only works over HTTPS** — which matters in a training where
commands get pasted all day.

Leave `dns_zone` out and none of this happens: `make dns` is a no-op, no
certificate, plain HTTP on port 80, exactly as before. That is also the rollback
path — remove it, then `make up && make configure` puts the web app back on port
80 (and `make delete-dns` drops the record itself).

Two things to know when switching a live server:

- Port 80 changes hands (from the `guacamole` container to `caddy`), so the role
  brings the stack down and back up. Live browser sessions are cut — do it
  outside a training session. No account or connection is lost: the database is
  a named volume.
- The certificate is requested when Caddy starts and needs the name to resolve
  to this server. Check with `dig +short A training.k8s-school.fr`, and read
  `docker compose -f /opt/guacamole/docker-compose.yml logs caddy` if the URL
  stays silent.

> Skeleton: search for `TODO` before first real use (credentials, image IDs,
> pinned versions). The Ansible roles intentionally reproduce the logic of the
> current `bootstrap/*` scripts, but idempotently.

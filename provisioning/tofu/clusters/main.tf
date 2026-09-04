# Two-node kubeadm clusters, one per participant, for labs/0_kubeadm of
# k8s-school/k8s-advanced. That lab is the only one of the course that cannot
# run on kind: building a control plane by hand needs real machines.
#
# A root module of its own, with its own state, for the reason that matters:
# lifetime. The training server next door (tofu/) lives for the whole session
# behind a reserved IP carrying prevent_destroy; these clusters are booted for
# a two-hour lab and destroyed right after. Keeping them in the same state
# would mean one `destroy` could not be run without endangering the other.
#
# Naming is the pivot of the design: the VMs of participant <I> are named
# student<I>-1 (master) and student<I>-2 (worker), after the account the
# participants role already creates on the training server. That is what lets
# labs/0_kubeadm/env.sh derive the cluster from $USER — nothing generated per
# participant, nothing to type, and the Kubernetes node names read the same as
# the SSH host names because Scaleway takes the hostname from the VM name.

locals {
  # Tag carried by every resource here, so that a leftover is trivial to spot:
  #   scw instance server list tags.0=kubeadm-lab
  #   scw instance ip list tags.0=kubeadm-lab
  tag = "kubeadm-lab"

  students = [
    for i in range(var.user_start, var.user_start + var.cluster_count) :
    "${var.user_prefix}${i}"
  ]

  # "student3-1" => { student = "student3", role = "master", type = "DEV1-M" }
  #
  # for_each over this map rather than count over a list: destroying one
  # cluster must not shift the index of every cluster after it, which is
  # exactly what count does — and what would rebuild half the room.
  nodes = merge([
    for s in local.students : {
      "${s}-1" = { student = s, role = "master", type = var.master_type }
      "${s}-2" = { student = s, role = "worker", type = var.worker_type }
    }
  ]...)

  summary = join("\n", concat(
    [format("%-14s %-16s %s", "PARTICIPANT", "MASTER (-1)", "WORKER (-2)")],
    [
      for s in local.students : format(
        "%-14s %-16s %s",
        s,
        scaleway_instance_ip.node["${s}-1"].address,
        scaleway_instance_ip.node["${s}-2"].address,
      )
    ],
  ))
}

# One key pair per participant, not one for the room: a participant can only
# reach their own two nodes, so a stray `kubeadm reset` cannot take down the
# neighbour's lab. The private key is handed to the account by the
# lab_clusters Ansible role.
resource "tls_private_key" "student" {
  for_each = toset(local.students)

  algorithm = "ED25519"
}

# No prevent_destroy here, unlike the training server's reserved IP: these
# addresses are meant to disappear with the cluster. An IP that outlives its
# VM keeps being billed, and it is the classic way a training session quietly
# costs money for weeks — hence the tag above and step 6 of the verification.
resource "scaleway_instance_ip" "node" {
  for_each = local.nodes

  zone = var.zone
  tags = [local.tag, each.value.student, each.key]
}

resource "scaleway_instance_server" "node" {
  for_each = local.nodes

  name  = each.key # also the hostname, hence the Kubernetes node name
  type  = each.value.type
  image = var.image
  zone  = var.zone
  ip_id = scaleway_instance_ip.node[each.key].id
  tags  = [local.tag, each.value.student, each.value.role]

  root_volume {
    size_in_gb            = var.root_volume_size_gb
    delete_on_termination = true
  }

  # The key is written to a file and appended, rather than declared under
  # `ssh_authorized_keys`, so that nothing competes with the keys Scaleway
  # injects from the project: the trainer keeps their own access to every node.
  # A YAML block scalar also spares us any quoting question about the key.
  user_data = {
    "cloud-init" = <<-EOT
      #cloud-config
      write_files:
        - path: /etc/ssh/participant_key.pub
          permissions: '0644'
          content: |
            ${indent(8, trimspace(tls_private_key.student[each.value.student].public_key_openssh))}
      runcmd:
        - install -d -m 0700 -o ${var.ssh_user} -g ${var.ssh_user} /home/${var.ssh_user}/.ssh
        - sh -c 'cat /etc/ssh/participant_key.pub >> /home/${var.ssh_user}/.ssh/authorized_keys'
        - chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.ssh/authorized_keys
        - chmod 0600 /home/${var.ssh_user}/.ssh/authorized_keys
    EOT
  }
}

# Human-readable recap for the trainer: which participant got which addresses.
resource "local_file" "summary" {
  filename = "${path.module}/clusters.txt"
  content  = "${local.summary}\n"
}

# Machine-readable twin of the above, plus the private keys, consumed by the
# lab_clusters Ansible role (`make cluster-dispatch`). It holds private keys,
# so it is mode 0600 and gitignored.
#
# Deliberately NOT under ansible/inventory/: ansible.cfg points `inventory` at
# that whole directory, so a file living there is handed to the inventory
# parsers, and this one is plain data — the playbook loads it with vars_files.
resource "local_file" "ansible_data" {
  filename        = "${path.module}/../../ansible/data/clusters.yml"
  file_permission = "0600"
  content = yamlencode({
    lab_clusters = [
      for s in local.students : {
        student     = s
        ssh_user    = var.ssh_user
        master      = { name = "${s}-1", ip = scaleway_instance_ip.node["${s}-1"].address }
        worker      = { name = "${s}-2", ip = scaleway_instance_ip.node["${s}-2"].address }
        private_key = tls_private_key.student[s].private_key_openssh
      }
    ]
  })
}

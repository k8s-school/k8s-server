output "summary" {
  description = "Participant-to-address table, as printed by `make cluster` and `make cluster-list`."
  value       = local.summary
}

output "clusters" {
  description = "Per-participant node names and public addresses."
  value = {
    for s in local.students : s => {
      master = { name = "${s}-1", ip = scaleway_instance_ip.node["${s}-1"].address }
      worker = { name = "${s}-2", ip = scaleway_instance_ip.node["${s}-2"].address }
    }
  }
}

output "node_ips" {
  description = "Flat node-name-to-address map, used by `make cluster-ssh node=<name>`."
  value       = { for name, ip in scaleway_instance_ip.node : name => ip.address }
}

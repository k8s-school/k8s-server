output "public_ip" {
  description = "Public IP of the training instance (the reserved, tagged IP)."
  value       = scaleway_instance_ip.main.address
}

output "fqdn" {
  description = "Public name of the training instance; empty when no dns_zone is declared."
  value       = local.fqdn
}

output "instance_id" {
  value = scaleway_instance_server.main.id
}

output "ssh_command" {
  description = "Admin access, via the operator key (same as 'make ssh'). Participants log in as student<N>, the instructor as trainer."
  value       = "ssh root@${scaleway_instance_ip.main.address}"
}

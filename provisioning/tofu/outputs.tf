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
  value = "ssh k8s0@${scaleway_instance_ip.main.address}"
}

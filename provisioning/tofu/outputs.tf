output "public_ip" {
  description = "Public IP of the training instance (the reserved, tagged IP)."
  value       = scaleway_instance_ip.main.address
}

output "instance_id" {
  value = scaleway_instance_server.main.id
}

output "ssh_command" {
  value = "ssh k8s0@${scaleway_instance_ip.main.address}"
}

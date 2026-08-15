output "fqdn" {
  description = "Public name now resolving to the training server."
  value       = "${var.dns_subdomain}.${var.dns_zone}"
}

output "target_ip" {
  description = "Address the record points at."
  value       = ovh_domain_zone_record.training.target
}

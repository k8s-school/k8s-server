# Public DNS record for the training server, in an OVH-hosted zone.
#
# Guacamole needs a real name, not an IP: Let's Encrypt validates names, and the
# HTTPS switch exists so the browser Clipboard API works — it is restricted to
# secure contexts. Managing the record here rather than by hand in the OVH panel
# keeps the name and the address it resolves to in the same place.
#
# Applied by `make dns FLAVOR=<flavor>`, which reads dns_zone / dns_subdomain
# from the flavor's tfvars and passes the reserved IP from the main state.
resource "ovh_domain_zone_record" "training" {
  zone      = var.dns_zone
  subdomain = var.dns_subdomain
  fieldtype = "A"
  target    = var.target_ip
  ttl       = var.dns_ttl
}

# No zone-refresh resource on purpose: OVH serves the zone from a generated
# file, so a record only becomes visible to resolvers once the zone is
# refreshed — but the provider posts that refresh itself after every create,
# update and delete (ovhDomainZoneRefresh in resource_domain_zone_record.go).
# The standalone ovh_domain_zone_refresh resource that used to do it no longer
# exists in provider v2.

# -----------------------------------------------------------------------------
# Certificate ARNs
# -----------------------------------------------------------------------------

output "certificate_arns" {
  description = "ACM certificate ARNs."

  value = module.acm.certificate_arns
}

# -----------------------------------------------------------------------------
# Certificate Status
# -----------------------------------------------------------------------------

output "certificate_statuses" {
  description = "Current ACM certificate statuses."

  value = module.acm.certificate_statuses
}

# -----------------------------------------------------------------------------
# Validation Records
# -----------------------------------------------------------------------------

output "validation_record_fqdns" {
  description = "Route 53 DNS validation record FQDNs."

  value = module.acm.validation_record_fqdns
}

# -----------------------------------------------------------------------------
# Validated Certificate ARNs
# -----------------------------------------------------------------------------

output "validated_certificate_arns" {
  description = "ACM certificate ARNs that completed DNS validation."

  value = module.acm.validated_certificate_arns
}
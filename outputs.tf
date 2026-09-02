# -----------------------------------------------------------------------------
# Certificate ARNs
# -----------------------------------------------------------------------------

output "certificate_arns" {
  description = "Map of certificate names to ACM certificate ARNs."

  value = {
    for name, certificate in aws_acm_certificate.this :
    name => certificate.arn
  }
}

# -----------------------------------------------------------------------------
# Certificate IDs
# -----------------------------------------------------------------------------

output "certificate_ids" {
  description = "Map of certificate names to ACM certificate IDs."

  value = {
    for name, certificate in aws_acm_certificate.this :
    name => certificate.id
  }
}

# -----------------------------------------------------------------------------
# Primary Domain Names
# -----------------------------------------------------------------------------

output "certificate_domain_names" {
  description = "Map of certificate names to primary domain names."

  value = {
    for name, certificate in aws_acm_certificate.this :
    name => certificate.domain_name
  }
}

# -----------------------------------------------------------------------------
# Certificate Status
# -----------------------------------------------------------------------------

output "certificate_statuses" {
  description = "Map of certificate names to ACM certificate statuses."

  value = {
    for name, certificate in aws_acm_certificate.this :
    name => certificate.status
  }
}

# -----------------------------------------------------------------------------
# Validation Methods
# -----------------------------------------------------------------------------

output "certificate_validation_methods" {
  description = "Map of certificate names to ACM validation methods."

  value = {
    for name, certificate in aws_acm_certificate.this :
    name => certificate.validation_method
  }
}

# -----------------------------------------------------------------------------
# Domain Validation Options
# -----------------------------------------------------------------------------
# Exposes the raw ACM validation information for troubleshooting or for
# integrations where DNS records are managed outside this module.
# -----------------------------------------------------------------------------

output "certificate_domain_validation_options" {
  description = "Map of certificate names to ACM domain validation options."

  value = {
    for name, certificate in aws_acm_certificate.this :
    name => certificate.domain_validation_options
  }
}

# -----------------------------------------------------------------------------
# Route 53 Validation Record FQDNs
# -----------------------------------------------------------------------------
# Returns the DNS validation records associated with each certificate.
#
# The same Route 53 validation record may appear for certificates requested
# in different AWS Regions because ACM validation records can be reused.
# -----------------------------------------------------------------------------

output "validation_record_fqdns" {
  description = "Map of certificate names to Route 53 DNS validation record FQDNs."

  value = {
    for certificate_name in keys(local.dns_validated_certificates) :
    certificate_name => [
      for record_key in local.validation_records_by_certificate[certificate_name] :
      aws_route53_record.validation[record_key].fqdn
    ]
  }
}

# -----------------------------------------------------------------------------
# Validated Certificate ARNs
# -----------------------------------------------------------------------------
# Contains certificates for which Terraform waited for DNS validation.
# -----------------------------------------------------------------------------

output "validated_certificate_arns" {
  description = "Map of certificate names to validated ACM certificate ARNs."

  value = {
    for name, certificate in aws_acm_certificate_validation.this :
    name => certificate.certificate_arn
  }
}
# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------
# Centralizes values derived from the module inputs.
# -----------------------------------------------------------------------------

locals {
  # ---------------------------------------------------------------------------
  # Common Tags
  # ---------------------------------------------------------------------------

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "acm"
    },
    var.tags
  )

  # ---------------------------------------------------------------------------
  # DNS-Validated Certificates
  # ---------------------------------------------------------------------------

  dns_validated_certificates = {
    for name, certificate in var.certificates :
    name => certificate
    if upper(certificate.validation_method) == "DNS"
  }

  # ---------------------------------------------------------------------------
  # Email-Validated Certificates
  # ---------------------------------------------------------------------------

  email_validated_certificates = {
    for name, certificate in var.certificates :
    name => certificate
    if upper(certificate.validation_method) == "EMAIL"
  }

  # ---------------------------------------------------------------------------
  # Certificate Domains
  # ---------------------------------------------------------------------------
  # Combines the primary domain and SANs for every DNS-validated certificate.
  #
  # Wildcard domains are normalized by removing "*." because ACM uses the
  # same DNS validation record for a wildcard and its corresponding base
  # domain.
  # ---------------------------------------------------------------------------

  certificate_domains = flatten([
    for certificate_name, certificate in local.dns_validated_certificates : [
      for domain in concat(
        [certificate.domain_name],
        certificate.subject_alternative_names
        ) : {
        certificate_name = certificate_name
        domain_name      = domain

        normalized_name = (
          startswith(domain, "*.")
          ? trimprefix(domain, "*.")
          : domain
        )

        zone_id = (
          certificate.route53_zone_id != null
          ? certificate.route53_zone_id
          : lookup(
            certificate.route53_zone_ids,
            domain,
            lookup(
              certificate.route53_zone_ids,
              startswith(domain, "*.")
              ? trimprefix(domain, "*.")
              : domain,
              null
            )
          )
        )
      }
    ]
  ])

  # ---------------------------------------------------------------------------
  # Unique Validation Records
  # ---------------------------------------------------------------------------
  # ACM DNS validation records can be reused across AWS Regions.
  #
  # Therefore the certificate name is intentionally NOT part of this key.
  #
  # Example:
  #
  #   certificate-eu -> example.com -> Z123
  #   certificate-us -> example.com -> Z123
  #
  # results in one Route 53 validation record instead of two Terraform
  # resources managing the same DNS record.
  # ---------------------------------------------------------------------------

  unique_validation_domains = {
    for item in local.certificate_domains :
    "${item.zone_id}:${item.normalized_name}" => item
  }

  # -----------------------------------------------------------------------------
  # Validation Records Per Certificate
  # -----------------------------------------------------------------------------
  # Determines which shared validation records are required by each certificate.
  #
  # A validation record may be shared by certificates in different AWS Regions.
  # Therefore, the mapping is based on the certificate's requested domains
  # rather than on which certificate originally created the unique record.
  # -----------------------------------------------------------------------------

  validation_records_by_certificate = {
    for certificate_name, certificate in local.dns_validated_certificates :
    certificate_name => [
      for record_key, record in local.unique_validation_domains :
      record_key
      if anytrue([
        for domain in concat(
          [certificate.domain_name],
          certificate.subject_alternative_names
        ) :
        record.zone_id == (
          certificate.route53_zone_id != null
          ? certificate.route53_zone_id
          : lookup(
            certificate.route53_zone_ids,
            domain,
            lookup(
              certificate.route53_zone_ids,
              startswith(domain, "*.")
              ? trimprefix(domain, "*.")
              : domain,
              null
            )
          )
        )
        &&
        record.normalized_name == (
          startswith(domain, "*.")
          ? trimprefix(domain, "*.")
          : domain
        )
      ])
    ]
  }
}
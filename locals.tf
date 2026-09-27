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
  # One Route 53 record per validation name, keyed by the normalized domain.
  #
  # The key must be known at plan time, because it becomes the for_each key of
  # aws_route53_record.validation. The domain names are; the hosted zone ID is
  # often not (a zone created in the same apply), so the zone travels in the
  # value, never in the key.
  #
  # Several entries share a key and collapse into one record:
  #
  #   example.com and *.example.com  -> one ACM validation name
  #   the same domain on certificates in different AWS Regions
  #                                  -> the same validation name (ACM reuses
  #                                     it across Regions within an account)
  #
  # The first entry for each name supplies the certificate whose validation
  # options are read and the zone the record is written to.
  # ---------------------------------------------------------------------------

  validation_domains_by_name = {
    for item in local.certificate_domains :
    item.normalized_name => item...
  }

  unique_validation_domains = {
    for name, items in local.validation_domains_by_name :
    name => items[0]
  }

  # -----------------------------------------------------------------------------
  # Validation Records Per Certificate
  # -----------------------------------------------------------------------------
  # The validation record keys (normalized domains) each certificate needs.
  # -----------------------------------------------------------------------------

  validation_records_by_certificate = {
    for certificate_name, certificate in local.dns_validated_certificates :
    certificate_name => distinct([
      for domain in concat(
        [certificate.domain_name],
        certificate.subject_alternative_names
      ) :
      startswith(domain, "*.") ? trimprefix(domain, "*.") : domain
    ])
  }
}

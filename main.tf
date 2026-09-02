# -----------------------------------------------------------------------------
# ACM Certificate
# -----------------------------------------------------------------------------
# Creates Amazon Certificate Manager certificates.
#
# Each certificate is created in the AWS Region specified by
# each.value.region.
#
# Supported:
#   - Single-domain certificates
#   - SAN certificates
#   - Wildcard certificates
#   - DNS validation
#   - Email validation
#   - RSA keys
#   - ECC keys
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "this" {
  for_each = var.certificates

  # ---------------------------------------------------------------------------
  # Certificate Region
  # ---------------------------------------------------------------------------
  # ACM certificates are regional resources.
  # ---------------------------------------------------------------------------

  region = each.value.region

  domain_name = each.value.domain_name

  subject_alternative_names = each.value.subject_alternative_names

  validation_method = upper(
    each.value.validation_method
  )

  key_algorithm = each.value.key_algorithm

  tags = merge(
    local.common_tags,
    {
      Name = coalesce(
        lookup(each.value.tags, "Name", null),
        "${var.project_name}-${var.environment}-${each.key}-certificate"
      )
    },
    each.value.tags
  )

  # ---------------------------------------------------------------------------
  # Certificate Replacement
  # ---------------------------------------------------------------------------
  # Creates a replacement certificate before destroying the existing one.
  # This is important for certificates attached to production resources.
  # ---------------------------------------------------------------------------

  lifecycle {
    create_before_destroy = true

    precondition {
      condition = (
        upper(each.value.validation_method) == "DNS"
        ? (
          each.value.route53_zone_id != null ||
          length(each.value.route53_zone_ids) > 0
        )
        : true
      )

      error_message = "DNS validation requires either route53_zone_id or route53_zone_ids."
    }
  }
}

# -----------------------------------------------------------------------------
# Route 53 DNS Validation Records
# -----------------------------------------------------------------------------
# Creates ACM DNS validation CNAME records in the supplied Route 53 hosted
# zones.
#
# The validation records are intentionally independent of the ACM certificate
# Region because Route 53 is used as the DNS control plane.
#
# The same ACM validation CNAME can be reused for certificates requested in
# multiple AWS Regions.
# -----------------------------------------------------------------------------

resource "aws_route53_record" "validation" {
  for_each = local.unique_validation_domains

  allow_overwrite = true

  # ---------------------------------------------------------------------------
  # ACM Validation Record Name
  # ---------------------------------------------------------------------------

  name = one([
    for dvo in aws_acm_certificate.this[each.value.certificate_name].domain_validation_options :
    dvo.resource_record_name
    if(
      dvo.domain_name == each.value.domain_name ||
      dvo.domain_name == each.value.normalized_name ||
      (
        startswith(dvo.domain_name, "*.") &&
        trimprefix(dvo.domain_name, "*.") == each.value.normalized_name
      )
    )
  ])

  # ---------------------------------------------------------------------------
  # ACM Validation Record Value
  # ---------------------------------------------------------------------------

  records = [
    one([
      for dvo in aws_acm_certificate.this[each.value.certificate_name].domain_validation_options :
      dvo.resource_record_value
      if(
        dvo.domain_name == each.value.domain_name ||
        dvo.domain_name == each.value.normalized_name ||
        (
          startswith(dvo.domain_name, "*.") &&
          trimprefix(dvo.domain_name, "*.") == each.value.normalized_name
        )
      )
    ])
  ]

  # ---------------------------------------------------------------------------
  # ACM Validation Record Type
  # ---------------------------------------------------------------------------

  type = one([
    for dvo in aws_acm_certificate.this[each.value.certificate_name].domain_validation_options :
    dvo.resource_record_type
    if(
      dvo.domain_name == each.value.domain_name ||
      dvo.domain_name == each.value.normalized_name ||
      (
        startswith(dvo.domain_name, "*.") &&
        trimprefix(dvo.domain_name, "*.") == each.value.normalized_name
      )
    )
  ])

  zone_id = each.value.zone_id

  ttl = 60
}

# -----------------------------------------------------------------------------
# ACM Certificate Validation
# -----------------------------------------------------------------------------
# Waits for ACM to detect the DNS validation records and issue the certificate.
#
# The validation resource is created in the same AWS Region as its ACM
# certificate.
# -----------------------------------------------------------------------------

resource "aws_acm_certificate_validation" "this" {
  for_each = {
    for name, certificate in local.dns_validated_certificates :
    name => certificate
    if certificate.wait_for_validation
  }

  region = each.value.region

  certificate_arn = aws_acm_certificate.this[each.key].arn

  validation_record_fqdns = [
    for record_key in local.validation_records_by_certificate[each.key] :
    aws_route53_record.validation[record_key].fqdn
  ]

  depends_on = [
    aws_route53_record.validation
  ]
}
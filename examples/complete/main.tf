# -----------------------------------------------------------------------------
# ACM Complete Example
# -----------------------------------------------------------------------------
# Demonstrates creation of an ACM certificate with:
#
#   - A specified AWS Region
#   - A primary domain
#   - SANs
#   - A wildcard domain
#   - DNS validation
#   - Automatic Route 53 validation records
#   - Automatic certificate validation
#
# The Route 53 hosted zone must already exist.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AWS Provider
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# ACM Module
# -----------------------------------------------------------------------------

module "acm" {
  source = "../.."

  project_name = var.project_name
  environment  = var.environment

  certificates = {
    primary = {
      # ACM is regional, so the certificate's Region is explicitly configured.
      region = var.certificate_region

      domain_name = var.domain_name

      subject_alternative_names = [
        "*.${var.domain_name}",
        "www.${var.domain_name}",
        "api.${var.domain_name}"
      ]

      validation_method = "DNS"

      route53_zone_id = var.route53_zone_id

      wait_for_validation = true

      key_algorithm = "RSA_2048"

      tags = {
        Purpose = "Application TLS"
      }
    }
  }

  tags = {
    Owner = "Infrastructure"
  }
}
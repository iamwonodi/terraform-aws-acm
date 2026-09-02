# -----------------------------------------------------------------------------
# Project Name
# -----------------------------------------------------------------------------
# Logical name of the project. Used for resource naming and default tags.
# -----------------------------------------------------------------------------

variable "project_name" {
  type        = string
  description = "Name of the project used for resource naming and default tags."

  validation {
    condition     = trimspace(var.project_name) != ""
    error_message = "project_name must not be empty."
  }
}

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------
# Deployment environment, such as dev, staging, or production.
# -----------------------------------------------------------------------------

variable "environment" {
  type        = string
  description = "Deployment environment used for resource naming and default tags."

  validation {
    condition     = trimspace(var.environment) != ""
    error_message = "environment must not be empty."
  }
}

# -----------------------------------------------------------------------------
# ACM Certificates
# -----------------------------------------------------------------------------
# Defines one or more ACM certificates.
#
# Each certificate specifies its own AWS Region because ACM certificates are
# regional resources.
#
# DNS validation can use either:
#
#   1. route53_zone_id
#      One Route 53 hosted zone for all certificate domains.
#
#   2. route53_zone_ids
#      Individual hosted zone IDs mapped to certificate domains.
#
# This allows a single module invocation to manage certificates across
# multiple AWS Regions and multiple Route 53 hosted zones.
# -----------------------------------------------------------------------------

variable "certificates" {
  description = "Map of ACM certificates to create."

  type = map(object({
    # -------------------------------------------------------------------------
    # ACM Region
    # -------------------------------------------------------------------------
    # AWS Region where this specific ACM certificate is requested.
    # -------------------------------------------------------------------------

    region = string

    domain_name = string

    subject_alternative_names = optional(
      list(string),
      []
    )

    validation_method = optional(
      string,
      "DNS"
    )

    route53_zone_id = optional(
      string,
      null
    )

    route53_zone_ids = optional(
      map(string),
      {}
    )

    wait_for_validation = optional(
      bool,
      true
    )

    key_algorithm = optional(
      string,
      "RSA_2048"
    )

    tags = optional(
      map(string),
      {}
    )
  }))

  validation {
    condition = length(var.certificates) > 0

    error_message = "certificates must contain at least one certificate."
  }

  validation {
    condition = alltrue([
      for name, certificate in var.certificates :
      trimspace(name) != ""
    ])

    error_message = "Every certificate map key must not be empty."
  }

  # ---------------------------------------------------------------------------
  # Region Validation
  # ---------------------------------------------------------------------------

  validation {
    condition = alltrue([
      for name, certificate in var.certificates :
      trimspace(certificate.region) != ""
    ])

    error_message = "Every ACM certificate must specify a non-empty AWS region."
  }

  # ---------------------------------------------------------------------------
  # Domain Validation
  # ---------------------------------------------------------------------------

  validation {
    condition = alltrue([
      for name, certificate in var.certificates :
      trimspace(certificate.domain_name) != ""
    ])

    error_message = "Every certificate must contain a non-empty domain_name."
  }

  # ---------------------------------------------------------------------------
  # Validation Method
  # ---------------------------------------------------------------------------

  validation {
    condition = alltrue([
      for name, certificate in var.certificates :
      contains(
        ["DNS", "EMAIL"],
        upper(certificate.validation_method)
      )
    ])

    error_message = "validation_method must be either DNS or EMAIL."
  }

  # ---------------------------------------------------------------------------
  # DNS Validation Zone Requirement
  # ---------------------------------------------------------------------------

  validation {
    condition = alltrue([
      for name, certificate in var.certificates :
      upper(certificate.validation_method) == "DNS"
      ? (
        certificate.route53_zone_id != null ||
        length(certificate.route53_zone_ids) > 0
      )
      : true
    ])

    error_message = "DNS validation requires either route53_zone_id or route53_zone_ids."
  }

  # ---------------------------------------------------------------------------
  # Mutually Exclusive Route 53 Configuration
  # ---------------------------------------------------------------------------

  validation {
    condition = alltrue([
      for name, certificate in var.certificates :
      !(
        certificate.route53_zone_id != null &&
        length(certificate.route53_zone_ids) > 0
      )
    ])

    error_message = "Use either route53_zone_id or route53_zone_ids, not both."
  }

  # ---------------------------------------------------------------------------
  # Email Validation
  # ---------------------------------------------------------------------------
  # Route 53 configuration is unnecessary when email validation is used.
  # ---------------------------------------------------------------------------

  validation {
    condition = alltrue([
      for name, certificate in var.certificates :
      upper(certificate.validation_method) == "EMAIL"
      ? (
        certificate.route53_zone_id == null &&
        length(certificate.route53_zone_ids) == 0
      )
      : true
    ])

    error_message = "Route 53 zone IDs must not be supplied when using EMAIL validation."
  }

  # ---------------------------------------------------------------------------
  # Key Algorithm
  # ---------------------------------------------------------------------------

  validation {
    condition = alltrue([
      for name, certificate in var.certificates :
      contains(
        [
          "RSA_1024",
          "RSA_2048",
          "RSA_3072",
          "RSA_4096",
          "EC_prime256v1",
          "EC_secp384r1",
          "EC_secp521r1"
        ],
        certificate.key_algorithm
      )
    ])

    error_message = "key_algorithm must be a supported ACM RSA or EC algorithm."
  }
}

# -----------------------------------------------------------------------------
# Common Tags
# -----------------------------------------------------------------------------

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to ACM certificates."
  default     = {}
}
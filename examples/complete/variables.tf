# -----------------------------------------------------------------------------
# AWS Region
# -----------------------------------------------------------------------------
# Region used by the example ACM certificate.
# -----------------------------------------------------------------------------

variable "aws_region" {
  type        = string
  description = "AWS region used by the Terraform AWS provider."
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Project Name
# -----------------------------------------------------------------------------

variable "project_name" {
  type        = string
  description = "Project name used by the ACM module."
  default     = "example"
}

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "dev"
}

# -----------------------------------------------------------------------------
# ACM Certificate Region
# -----------------------------------------------------------------------------

variable "certificate_region" {
  type        = string
  description = "AWS Region where the ACM certificate is requested."
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Domain Name
# -----------------------------------------------------------------------------

variable "domain_name" {
  type        = string
  description = "Primary domain name for the ACM certificate."
  default     = "example.com"
}

# -----------------------------------------------------------------------------
# Route 53 Hosted Zone ID
# -----------------------------------------------------------------------------

variable "route53_zone_id" {
  type        = string
  description = "Existing Route 53 hosted zone ID used for ACM DNS validation."

  validation {
    condition     = trimspace(var.route53_zone_id) != ""
    error_message = "route53_zone_id must not be empty."
  }
}
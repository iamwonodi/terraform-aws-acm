# Terraform AWS ACM Module

A reusable, secure-by-default Terraform module for creating and managing **AWS Certificate Manager (ACM)** certificates.

The module supports:

* Single-domain certificates
* Subject Alternative Names (SANs)
* Wildcard certificates
* DNS validation
* Email validation
* Automatic Route 53 DNS validation records
* Multiple certificates from a single module invocation
* Certificates in multiple AWS Regions
* Multiple Route 53 hosted zones
* RSA and ECC certificate keys
* Automatic certificate validation
* `create_before_destroy` lifecycle protection
* Consistent project and environment tagging

---

## Architecture

```text
                         ┌──────────────────────────┐
                         │      Terraform Caller    │
                         │                          │
                         │  certificates = { ... }  │
                         └────────────┬─────────────┘
                                      │
                                      ▼
                         ┌──────────────────────────┐
                         │       ACM Module         │
                         │                          │
                         │  aws_acm_certificate     │
                         └────────────┬─────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │                                   │
                    ▼                                   ▼
          ┌───────────────────┐              ┌────────────────────┐
          │ Route 53 Hosted   │              │ ACM Certificate    │
          │ Zone(s)            │              │ Validation         │
          │                    │              │                    │
          │ DNS CNAME records  │─────────────►│ Certificate issued  │
          └───────────────────┘              └──────────┬─────────┘
                                                        │
                                                        ▼
                                           ┌────────────────────────┐
                                           │ AWS Service             │
                                           │                        │
                                           │ ALB / CloudFront /     │
                                           │ API Gateway / etc.     │
                                           └────────────────────────┘
```

The ACM module creates the certificate and, when DNS validation is selected, can automatically create the required validation records in existing Route 53 hosted zones.

The resulting certificate can then be attached to AWS services such as Application Load Balancers, CloudFront distributions, and API Gateway.

---

# Important: ACM Certificates Are Regional

ACM certificates are **regional AWS resources**.

The AWS Region is therefore configured **per certificate**, rather than once at the module level.

For example, one module invocation can create:

```text
example.com
    │
    ├── us-east-1
    │      └── ACM certificate
    │
    ├── eu-west-1
    │      └── ACM certificate
    │
    └── af-south-1
           └── ACM certificate
```

This is useful when the same application is deployed across multiple AWS Regions.

The module therefore requires:

```hcl
certificates = {
  primary = {
    region = "us-east-1"

    domain_name = "example.com"
  }

  europe = {
    region = "eu-west-1"

    domain_name = "example.com"
  }
}
```

The certificates remain independent ACM resources even though they may use the same DNS validation records.

---

# CloudFront and `us-east-1`

If an ACM certificate will be used with **Amazon CloudFront**, the certificate must be created in:

```text
us-east-1
```

Example:

```hcl
certificates = {
  cloudfront = {
    region      = "us-east-1"
    domain_name = "example.com"
  }
}
```

Certificates intended for regional services such as an Application Load Balancer should normally be created in the same AWS Region as the service.

---

# DNS Validation

DNS validation is the recommended validation method for automated infrastructure deployments.

With DNS validation enabled, this module:

1. Requests the ACM certificate.
2. Reads the ACM domain validation options.
3. Creates the required Route 53 validation CNAME records.
4. Waits for ACM to detect the records.
5. Waits for ACM to issue the certificate.

The workflow is therefore:

```text
Terraform
   │
   ▼
Request ACM Certificate
   │
   ▼
ACM provides validation CNAME
   │
   ▼
Terraform creates Route 53 CNAME
   │
   ▼
ACM detects DNS record
   │
   ▼
Domain validated
   │
   ▼
Certificate issued
```

---

# Shared DNS Validation Across Regions

ACM DNS validation records can be reused when requesting certificates for the same domain in different AWS Regions.

For example:

```text
example.com
    │
    ├── Certificate in us-east-1
    │
    └── Certificate in eu-west-1
```

The module intentionally manages the corresponding validation record as a shared DNS record rather than creating duplicate Terraform resources for each regional certificate.

This allows one Route 53 validation record to support multiple regional ACM certificates.

---

# Supported Certificate Types

## Single Domain

```hcl
certificates = {
  application = {
    region      = "eu-west-1"
    domain_name = "example.com"

    validation_method = "DNS"

    route53_zone_id = "Z0123456789ABCDEF"
  }
}
```

---

## SAN Certificate

A certificate can contain multiple domains using `subject_alternative_names`.

```hcl
certificates = {
  application = {
    region      = "eu-west-1"
    domain_name = "example.com"

    subject_alternative_names = [
      "www.example.com",
      "api.example.com",
      "app.example.com"
    ]

    validation_method = "DNS"

    route53_zone_id = "Z0123456789ABCDEF"
  }
}
```

---

## Wildcard Certificate

Wildcard domains are supported:

```hcl
certificates = {
  application = {
    region      = "eu-west-1"
    domain_name = "*.example.com"

    validation_method = "DNS"

    route53_zone_id = "Z0123456789ABCDEF"
  }
}
```

A wildcard certificate such as:

```text
*.example.com
```

covers subdomains such as:

```text
www.example.com
api.example.com
app.example.com
```

but does not replace a certificate for:

```text
example.com
```

when the apex domain itself also needs to be covered.

A certificate can therefore contain both:

```hcl
domain_name = "example.com"

subject_alternative_names = [
  "*.example.com"
]
```

---

# Multiple Route 53 Hosted Zones

The module supports two approaches for DNS validation.

## Option 1 — One Hosted Zone

Use `route53_zone_id` when all certificate domains are managed by the same Route 53 hosted zone.

```hcl
route53_zone_id = "Z0123456789ABCDEF"
```

For example:

```text
example.com
www.example.com
api.example.com
*.example.com
```

can all use the same hosted zone.

---

## Option 2 — Multiple Hosted Zones

Use `route53_zone_ids` when certificate domains are managed by different hosted zones.

Example:

```hcl
route53_zone_ids = {
  "example.com"     = "Z111111111111111"
  "example.net"     = "Z222222222222222"
  "example.org"     = "Z333333333333333"
}
```

Then:

```hcl
certificates = {
  global = {
    region      = "us-east-1"
    domain_name = "example.com"

    subject_alternative_names = [
      "example.net",
      "example.org"
    ]

    validation_method = "DNS"

    route53_zone_ids = {
      "example.com" = "Z111111111111111"
      "example.net" = "Z222222222222222"
      "example.org" = "Z333333333333333"
    }
  }
}
```

For wildcard domains, the module also normalizes:

```text
*.example.com
```

to:

```text
example.com
```

when determining the Route 53 hosted zone.

---

# Email Validation

Email validation is also supported:

```hcl
certificates = {
  application = {
    region      = "eu-west-1"
    domain_name = "example.com"

    validation_method = "EMAIL"
  }
}
```

When using email validation:

* ACM sends validation emails to the domain's administrative contacts.
* Route 53 hosted zone IDs must not be supplied.
* Terraform cannot automatically complete the email approval process.

For automated infrastructure deployments, **DNS validation is generally preferred**.

---

# Key Algorithms

The module supports ACM RSA and ECC certificate algorithms.

Supported values:

```text
RSA_1024
RSA_2048
RSA_3072
RSA_4096

EC_prime256v1
EC_secp384r1
EC_secp521r1
```

The default is:

```hcl
key_algorithm = "RSA_2048"
```

Example ECC certificate:

```hcl
certificates = {
  application = {
    region        = "eu-west-1"
    domain_name   = "example.com"
    key_algorithm = "EC_prime256v1"

    validation_method = "DNS"

    route53_zone_id = "Z0123456789ABCDEF"
  }
}
```

Choose the algorithm based on the compatibility requirements of the AWS service and clients consuming the certificate.

---

# Complete Example

The complete example is located at:

```text
examples/complete/
```

Example structure:

```text
acm/
├── main.tf
├── variables.tf
├── locals.tf
├── outputs.tf
├── versions.tf
├── README.md
└── examples/
    └── complete/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

The example demonstrates:

* ACM certificate creation
* Regional certificate configuration
* SANs
* Wildcard certificates
* Route 53 DNS validation
* Automatic validation
* RSA 2048 certificates
* Module tagging

Example:

```hcl
module "acm" {
  source = "../.."

  project_name = var.project_name
  environment  = var.environment

  certificates = {
    primary = {
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
```

---

# Multi-Region Example

A single module invocation can manage certificates in multiple Regions.

```hcl
module "acm" {
  source = "../.."

  project_name = "global-application"
  environment  = "production"

  certificates = {
    cloudfront = {
      region      = "us-east-1"
      domain_name = "example.com"

      subject_alternative_names = [
        "*.example.com"
      ]

      validation_method = "DNS"

      route53_zone_id = "Z0123456789ABCDEF"
    }

    europe = {
      region      = "eu-west-1"
      domain_name = "example.com"

      subject_alternative_names = [
        "*.example.com"
      ]

      validation_method = "DNS"

      route53_zone_id = "Z0123456789ABCDEF"
    }
  }
}
```

This creates two independent ACM certificates while allowing the DNS validation records to be shared.

---

# Lifecycle Protection

The ACM certificate resource uses:

```hcl
lifecycle {
  create_before_destroy = true
}
```

This helps prevent an existing certificate from being destroyed before its replacement is available.

This is particularly important for certificates attached to production services.

---

# Tags

The module applies common tags to every ACM certificate.

Default tags include:

```text
Project
Environment
ManagedBy
Module
```

For example:

```text
Project     = "my-application"
Environment = "production"
ManagedBy   = "Terraform"
Module      = "acm"
```

Additional module-level tags can be supplied:

```hcl
tags = {
  Owner       = "Platform"
  CostCenter   = "Infrastructure"
}
```

Certificate-specific tags can also be supplied:

```hcl
certificates = {
  application = {
    region      = "eu-west-1"
    domain_name = "example.com"

    tags = {
      Purpose = "Application TLS"
    }
  }
}
```

Certificate-specific tags take precedence where the same tag key is supplied.

---

# Route 53 Requirements

When using DNS validation, the Route 53 hosted zone must already exist.

This module does **not** create the hosted zone.

For example:

```hcl
route53_zone_id = "Z0123456789ABCDEF"
```

must reference an existing hosted zone.

This design keeps the ACM module independent from the Route 53 hosted-zone module and allows it to work with:

* Existing Route 53 zones
* Zones created by another Terraform module
* Centrally managed DNS accounts
* Cross-account DNS architectures, where appropriate DNS permissions are provided

---

# Security Considerations

The module follows a secure and automation-friendly design.

## DNS Validation

DNS validation avoids manual approval emails and is well suited to Infrastructure as Code.

## Route 53

Only the ACM validation CNAME records required for certificate validation are created.

The module does not make the hosted zone public or modify unrelated DNS records.

## Certificate Replacement

`create_before_destroy` helps maintain certificate availability during Terraform changes.

## Existing DNS Ownership

The module assumes the caller controls or has permission to modify the specified Route 53 hosted zone.

---

# Inputs

| Name           | Type               | Default | Description                                                       |
| -------------- | ------------------ | ------- | ----------------------------------------------------------------- |
| `project_name` | `string`           | —       | Project name used for resource naming and default tags.           |
| `environment`  | `string`           | —       | Deployment environment used for resource naming and default tags. |
| `certificates` | `map(object(...))` | —       | Map of ACM certificates to create.                                |
| `tags`         | `map(string)`      | `{}`    | Additional tags applied to ACM certificates.                      |

## `certificates` Object

Each certificate supports:

| Attribute                   | Type           | Default      | Description                                             |
| --------------------------- | -------------- | ------------ | ------------------------------------------------------- |
| `region`                    | `string`       | required     | AWS Region where the certificate is requested.          |
| `domain_name`               | `string`       | required     | Primary domain name.                                    |
| `subject_alternative_names` | `list(string)` | `[]`         | Additional certificate domains.                         |
| `validation_method`         | `string`       | `"DNS"`      | ACM validation method: `DNS` or `EMAIL`.                |
| `route53_zone_id`           | `string`       | `null`       | Existing Route 53 hosted zone ID for DNS validation.    |
| `route53_zone_ids`          | `map(string)`  | `{}`         | Mapping of domains to Route 53 hosted zone IDs.         |
| `wait_for_validation`       | `bool`         | `true`       | Whether Terraform waits for ACM certificate validation. |
| `key_algorithm`             | `string`       | `"RSA_2048"` | ACM certificate key algorithm.                          |
| `tags`                      | `map(string)`  | `{}`         | Certificate-specific tags.                              |

---

# Input Validation

The module validates important configuration values before creating resources.

Examples include:

* At least one certificate must be supplied.
* Certificate names cannot be empty.
* Certificate Regions cannot be empty.
* Domain names cannot be empty.
* Validation method must be `DNS` or `EMAIL`.
* DNS validation requires a Route 53 hosted zone ID.
* `route53_zone_id` and `route53_zone_ids` cannot be used together.
* Route 53 zone IDs cannot be supplied with email validation.
* Key algorithms must be supported ACM algorithms.

This prevents common configuration mistakes before Terraform attempts to create AWS resources.

---

# Outputs

| Output                                  | Description                                                   |
| --------------------------------------- | ------------------------------------------------------------- |
| `certificate_arns`                      | Map of certificate names to ACM certificate ARNs.             |
| `certificate_ids`                       | Map of certificate names to ACM certificate IDs.              |
| `certificate_domain_names`              | Map of certificate names to primary domains.                  |
| `certificate_statuses`                  | Map of certificate names to ACM certificate statuses.         |
| `certificate_validation_methods`        | Map of certificate names to validation methods.               |
| `certificate_domain_validation_options` | Raw ACM domain validation options.                            |
| `validation_record_fqdns`               | DNS validation record FQDNs associated with each certificate. |
| `validated_certificate_arns`            | Certificates for which Terraform waited for validation.       |

---

# Using the Certificate with Other Modules

The most common pattern is to consume the certificate ARN from this module.

For example:

```hcl
module "acm" {
  source = "git::https://github.com/iamwonodi/terraform-aws-acm.git?ref=v1.0.1"

  project_name = "my-application"
  environment  = "production"

  certificates = {
    application = {
      region      = "eu-west-1"
      domain_name = "example.com"

      validation_method = "DNS"

      route53_zone_id = "Z0123456789ABCDEF"
    }
  }
}
```

Then another module can consume:

```hcl
module.acm.certificate_arns["application"]
```

For example:

```hcl
certificate_arn = module.acm.certificate_arns["application"]
```

This makes the ACM module reusable with:

* ALB modules
* CloudFront modules
* API Gateway modules
* Other AWS services supporting ACM certificates

---

# Terraform Requirements

Terraform:

```text
>= 1.6.0
```

AWS provider:

```text
>= 6.0.0, < 7.0.0
```

---

# Development and Validation

From the module root:

```powershell
terraform fmt -recursive
terraform init
terraform validate
```

Run the plan tests (mocked AWS provider, no credentials needed):

```powershell
terraform test
```

Validate the complete example:

```powershell
cd .\examples\complete

terraform init
terraform validate
```

Return to the module root:

```powershell
cd ..\..
```

Before applying the complete example, replace the example domain and Route 53 hosted zone ID with real values.

Then:

```powershell
terraform plan
```

and, when ready:

```powershell
terraform apply
```

---

# Destruction Considerations

Destroying an ACM certificate can affect AWS resources that depend on it.

Before running:

```powershell
terraform destroy
```

verify that the certificate is no longer required by:

* Application Load Balancers
* CloudFront distributions
* API Gateway
* Other AWS services

DNS validation records managed by this module will also be removed when the module is destroyed.

---

# Repository Structure

```text
terraform-aws-acm/
│
├── main.tf
├── variables.tf
├── locals.tf
├── outputs.tf
├── versions.tf
├── README.md
├── .terraform.lock.hcl
│
└── examples/
    └── complete/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

---

# Design Principles

This module follows the following design principles:

### Reusable

The module is designed to be consumed by multiple projects and environments.

### Secure by Default

DNS validation and controlled Route 53 records are preferred over manual certificate workflows.

### Regional Awareness

AWS Regions are defined per certificate because ACM certificates are regional resources.

### Provider Independence

The module does not depend on the Route 53 hosted-zone module. Existing hosted zones can be supplied directly.

### Multi-Certificate Support

Multiple certificates can be managed from a single module invocation.

### Terraform Lifecycle Safety

Certificates use `create_before_destroy` to reduce the risk of service disruption during replacement.

### Explicit Configuration

Important certificate properties such as Region, validation method, hosted zone, and key algorithm are explicitly configurable.

---

# Versioning

This module uses Git tags for releases.

Current release:

```text
v1.0.1
```

`v1.0.1` fixes DNS validation records:

* Records are keyed by the validated domain name instead of `<zone ID>:<domain>`, so the module plans when the hosted zone is created in the same apply (its ID is unknown until then).
* A domain and its wildcard (`example.com`, `*.example.com`), and the same domain on certificates in several Regions, share one record. `v1.0.0` failed on these with duplicate keys.

Inputs and outputs are unchanged.

Consume a released version:

```hcl
module "acm" {
  source = "git::https://github.com/iamwonodi/terraform-aws-acm.git?ref=v1.0.1"

  # ...
}
```

Do not consume an untagged branch for production infrastructure unless there is a specific reason to do so.

---

# Release Workflow

After modifying the module:

```powershell
terraform fmt -recursive
terraform init
terraform validate
```

Run the plan tests (mocked AWS provider, no credentials needed):

```powershell
terraform test
```

Validate the complete example:

```powershell
cd .\examples\complete
terraform init
terraform validate
cd ..\..
```

Review the changes:

```powershell
git status
git diff
```

Commit:

```powershell
git add .
git commit -m "feat: add reusable ACM module"
```

Create a release tag:

```powershell
git tag -a v1.0.0 -m "Release v1.0.0"
```

Push the branch and tag:

```powershell
git push origin main
git push origin v1.0.0
```

Verify:

```powershell
git status
git tag
```

---

# Summary

This ACM module provides a reusable Terraform interface for managing AWS TLS certificates across projects, environments, AWS Regions, and DNS zones.

Its primary workflow is:

```text
Terraform
   │
   ▼
ACM Certificate
   │
   ├── DNS Validation
   │       │
   │       ▼
   │   Route 53 CNAME
   │       │
   │       ▼
   │   ACM Validation
   │
   ▼
Issued Certificate
   │
   ├── ALB
   ├── CloudFront
   ├── API Gateway
   └── Other ACM-compatible services
```

The module is intentionally independent, configurable, and suitable for use as a building block within larger AWS Terraform architectures.

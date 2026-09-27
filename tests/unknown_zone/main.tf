# Calls the module with a hosted zone ID that is unknown until apply, as it is
# when the zone is created in the same apply as the certificates. Planned
# (never applied) by tests/plan.tftest.hcl.
terraform {
  required_providers {
    random = { source = "hashicorp/random" }
  }
}

resource "random_id" "zone" {
  byte_length = 8
}

module "acm" {
  source = "../.."

  project_name = "example"
  environment  = "test"

  certificates = {
    for name, region in { cloudfront = "us-east-1", default = "af-south-1" } :
    name => {
      region                    = region
      domain_name               = "dev.example.org"
      subject_alternative_names = ["www.dev.example.org", "*.dev.example.org"]
      validation_method         = "DNS"
      # The raw attribute: unknown until apply.
      route53_zone_id     = random_id.zone.b64_url
      wait_for_validation = true
    }
  }
}

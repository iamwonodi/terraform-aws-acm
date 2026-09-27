# Plans the module against a mocked AWS provider. Run with "terraform test"
# (or "tofu test") from the repository root.

mock_provider "aws" {
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      # ACM returns one entry per requested name; a wildcard shares its base
      # name's record.
      domain_validation_options = [
        { domain_name = "dev.example.org", resource_record_name = "_a.dev.example.org.", resource_record_type = "CNAME", resource_record_value = "_a.acm-validations.aws." },
        { domain_name = "*.dev.example.org", resource_record_name = "_a.dev.example.org.", resource_record_type = "CNAME", resource_record_value = "_a.acm-validations.aws." },
        { domain_name = "www.dev.example.org", resource_record_name = "_b.www.dev.example.org.", resource_record_type = "CNAME", resource_record_value = "_b.acm-validations.aws." },
      ]
    }
  }
}

run "shared_validation_names" {
  command = plan

  variables {
    project_name = "example"
    environment  = "test"

    certificates = {
      # The same names in two Regions, each with a wildcard of its own base.
      cloudfront = {
        region                    = "us-east-1"
        domain_name               = "dev.example.org"
        subject_alternative_names = ["www.dev.example.org", "*.dev.example.org"]
        validation_method         = "DNS"
        route53_zone_id           = "Z0123456789ABCDEFGHIJ"
        wait_for_validation       = true
      }
      default = {
        region                    = "af-south-1"
        domain_name               = "dev.example.org"
        subject_alternative_names = ["www.dev.example.org", "*.dev.example.org"]
        validation_method         = "DNS"
        route53_zone_id           = "Z0123456789ABCDEFGHIJ"
        wait_for_validation       = true
      }
    }
  }

  assert {
    condition     = toset(keys(aws_route53_record.validation)) == toset(["dev.example.org", "www.dev.example.org"])
    error_message = "Expected one record per validation name, keyed by domain."
  }

  assert {
    condition     = toset(local.validation_records_by_certificate["cloudfront"]) == toset(["dev.example.org", "www.dev.example.org"])
    error_message = "Each certificate should need both validation names."
  }
}

run "zone_id_unknown_until_apply" {
  command = plan

  module {
    source = "./tests/unknown_zone"
  }
}

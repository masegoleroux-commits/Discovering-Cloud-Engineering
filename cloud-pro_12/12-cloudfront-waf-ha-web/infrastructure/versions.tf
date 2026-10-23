terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

# CloudFront is a global service managed through us-east-1 (and so is a CLOUDFRONT-scope WAF).
# The skip_* settings stop this provider calling us-east-1 at all unless a resource uses it.
provider "aws" {
  alias                       = "us_east_1"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  default_tags {
    tags = local.common_tags
  }
}

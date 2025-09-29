terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider for the secondary region (us-east-1) where the core logic resides
provider "aws" {
  alias  = "secondary"
  region = var.aws_region_secondary
}

# Provider for the primary region (eu-north-1) for the webhook endpoint
provider "aws" {
  alias  = "primary"
  region = var.aws_region_primary
}

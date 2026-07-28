terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.id

  short_name  = coalesce(var.short_name, "tfstate")
  environment = var.environment
  name_prefix = "${local.short_name}-${local.environment}"

  bucket_name            = coalesce(var.s3_bucket_name, "${local.name_prefix}-tfstate-${local.aws_account_id}")
  s3_expiration_days     = var.s3_expiration_days
  block_public_access    = var.block_public_access
  versioning_enabled     = var.versioning_enabled
  server_side_encryption = var.server_side_encryption
}

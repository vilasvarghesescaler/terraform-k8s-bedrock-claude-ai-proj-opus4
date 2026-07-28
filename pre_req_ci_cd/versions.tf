terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 7.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }


  backend "s3" {
    key          = "vpc/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

provider "tls" {}

provider "github" {
  owner = var.github_org
  token = var.github_token # falls back to the GITHUB_TOKEN env var when null
}
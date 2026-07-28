# 1. AWS side: OIDC provider + CI/CD role
module "github_oidc_cicd" {
  source = "git::https://github.com/samarthsharma-maker/terraform-aws-github-oidc-cicd.git?ref=main"

  github_org  = var.github_org
  github_repo = var.github_repo

  short_name  = var.short_name
  environment = var.environment

  enable_region_lock            = true
  enable_critical_action_denies = false
  create_permission_boundary    = false
}

# 2. GitHub side: push the role ARN into the repo as a secret, plus the variables
module "github_secrets" {
  source = "git::https://github.com/samarthsharma-maker/terraform-github-actions-secrets.git?ref=main"

  repository = var.github_repo

  secrets = {
    AWS_ROLE_ARN = module.github_oidc_cicd.cicd_role_arn
  }

  variables = {
    AWS_REGION  = var.aws_region
    ENVIRONMENT = var.environment
  }
}
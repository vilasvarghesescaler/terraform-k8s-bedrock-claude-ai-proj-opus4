output "cicd_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions (also stored as the AWS_ROLE_ARN secret)."
  value       = module.github_oidc_cicd.cicd_role_arn
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN."
  value       = module.github_oidc_cicd.oidc_provider_arn
}

output "managed_secrets" {
  description = "Actions secrets created on the repository."
  value       = module.github_secrets.secret_names
}

output "managed_variables" {
  description = "Actions variables created on the repository."
  value       = module.github_secrets.variable_names
}
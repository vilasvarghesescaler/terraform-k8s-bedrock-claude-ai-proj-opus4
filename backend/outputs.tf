output "s3_bucket_id" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.terraform_state.arn
}

output "s3_bucket_region" {
  description = "Bucket region"
  value       = aws_s3_bucket.terraform_state.region
}

output "terraform_backend_config" {
  description = "Backend config to use in other projects"
  value = {
    bucket       = aws_s3_bucket.terraform_state.id
    key          = "terraform.tfstate"
    region       = local.aws_region
    encrypt      = local.server_side_encryption
    use_lockfile = true
  }
}

output "aws_region" {
  value = local.aws_region
}

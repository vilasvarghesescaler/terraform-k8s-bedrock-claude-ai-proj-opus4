# Temporary resource to verify the CI/CD pipeline works end to end.
# Free (SSM Standard parameters cost nothing), regional (us-east-1), safe.
# Delete this file once you've confirmed plan/apply run correctly.

resource "aws_ssm_parameter" "ci_check" {
  name  = "/ci-check/hello"
  type  = "String"
  value = "hello-from-terraform-ci"

  tags = {
    Purpose = "ci-pipeline-verification"
  }
}


output "ci_check_param" {
  description = "Name of the SSM parameter created by the CI check."
  value       = aws_ssm_parameter.ci_check.name
}

# aws_ecr.tf

resource "aws_ecr_repository" "services" {
  for_each     = toset(var.services)
  name         = join("-", [local.short_name, each.value])
  force_delete = true
  tags         = local.common_tags
}
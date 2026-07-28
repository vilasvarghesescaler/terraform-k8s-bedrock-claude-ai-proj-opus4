# aws_datastores_dynamodb.tf
resource "aws_db_subnet_group" "retail_store_db_subnets" {
  name       = local.db_subnet_group
  subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  tags       = local.common_tags
}

resource "aws_dynamodb_table" "carts" {
  name         = join("-", [local.cluster_name, "carts"])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.common_tags
}
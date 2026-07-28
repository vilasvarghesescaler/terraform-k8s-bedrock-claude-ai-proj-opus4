# aws_elasticache_redis.tf

resource "aws_elasticache_subnet_group" "retail_store_elasticache_subnets" {
  name       = local.db_subnet_group
  subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_elasticache_cluster" "checkout" {
  cluster_id         = join("-", [local.cluster_name, "elasticache", "redis", "checkout"])
  engine             = "redis"
  node_type          = var.checkout_redis_node_type
  num_cache_nodes    = 1
  subnet_group_name  = aws_elasticache_subnet_group.retail_store_elasticache_subnets.name
  security_group_ids = [aws_security_group.datastore_sg.id]
  tags               = local.common_tags
}
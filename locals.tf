# locals.tf

locals {
  account_id = data.aws_caller_identity.current.account_id
  registry   = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  region     = coalesce(data.aws_region.current.name, var.aws_region, "us-east-1")
  cidr       = coalesce(var.vpc_cidr, "10.0.0.0/16")
  short_name = coalesce(substr(var.cluster_name, 0, 3), "rs")

  # Mirrors AZ_1 / AZ_2 in the script (region + a / region + b).
  az_1                 = "${var.aws_region}a"
  az_2                 = "${var.aws_region}b"
  public_subnet_1_cidr = coalesce(var.public_subnet_1_cidr, "10.0.1.0/24")
  public_subnet_2_cidr = coalesce(var.public_subnet_2_cidr, "10.0.2.0/24")

  cluster_name      = coalesce(var.cluster_name, "scaler-eks-cluster")
  cluster_version   = coalesce(var.k8s_version, "1.36")
  node_min_size     = coalesce(var.node_min_size, 1)
  node_max_size     = coalesce(var.node_max_size, 3)
  node_desired_size = coalesce(var.node_desired_size, 2)

  # Resolve "null" identifier defaults to their cluster-prefixed names.
  catalog_db_id     = coalesce(var.catalog_db_id, "${local.cluster_name}-catalog-mysql")
  orders_db_id      = coalesce(var.orders_db_id, "${local.cluster_name}-orders-pg")
  checkout_redis_id = coalesce(var.checkout_redis_id, "${local.cluster_name}-checkout-redis")
  carts_ddb_table   = coalesce(var.carts_ddb_table, "${local.cluster_name}-carts")

  db_subnet_group = "${local.cluster_name}-db-subnets"

  common_tags = {
    Project = "retail-store"
    Cluster = local.cluster_name
  }
}
# aws_security_groups.tf

resource "aws_security_group" "datastore_sg" {
  name        = join("-", [local.cluster_name, "datastore", "sg"])
  description = "Datastore access for ${local.cluster_name} worker nodes"
  vpc_id      = aws_vpc.retail_store_vpc.id
  tags        = merge(local.common_tags, { Name = join("-", [local.cluster_name, "datastore", "sg"]) })

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow the EKS-managed cluster security group (worker nodes) to reach the
# datastore engine ports: MySQL 3306, PostgreSQL 5432, Redis 6379, AMQPS 5671.
resource "aws_security_group_rule" "datastore_ingress" {
  for_each                 = toset(["3306", "5432", "6379", "5671"])
  type                     = "ingress"
  from_port                = tonumber(each.value)
  to_port                  = tonumber(each.value)
  protocol                 = "tcp"
  security_group_id        = aws_security_group.datastore_sg.id
  source_security_group_id = aws_eks_cluster.scaler_retail_store_cluster.vpc_config[0].cluster_security_group_id
}

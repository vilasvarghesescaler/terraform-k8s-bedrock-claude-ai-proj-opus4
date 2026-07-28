# rabbitmq.tf

data "aws_mq_broker_engine_types" "rabbitmq" { engine_type = "RABBITMQ" }

locals {
  orders_mq_instance_type = "mq.m7g.large"

  rabbitmq_versions = data.aws_mq_broker_engine_types.rabbitmq.broker_engine_types[0].engine_versions[*].name

  # zero-pad each numeric segment so "3.9" sorts BELOW "3.13"
  # ("3.13" -> "0003.0013", "3.9.27" -> "0003.0009.0027")
  mq_version_keys = {
    for v in local.rabbitmq_versions :
    v => join(".", [for p in split(".", v) : format("%04d", tonumber(p))])
  }

  # the version whose padded key is the largest = newest
  mq_engine_version = one([
    for v, k in local.mq_version_keys :
    v if k == reverse(sort(values(local.mq_version_keys)))[0]
  ])
}

resource "random_password" "orders_mq" {
  length  = 20
  special = false
}

resource "aws_mq_broker" "orders" {
  broker_name                = join("-", [local.cluster_name, "orders", "mq"])
  engine_type                = "RabbitMQ"
  engine_version             = local.mq_engine_version
  host_instance_type         = local.orders_mq_instance_type
  deployment_mode            = "SINGLE_INSTANCE"
  publicly_accessible        = false
  auto_minor_version_upgrade = true

  subnet_ids      = [aws_subnet.public_1.id] # SINGLE_INSTANCE RabbitMQ uses exactly one subnet
  security_groups = [aws_security_group.datastore_sg.id]

  user {
    username = join("_", ["orders", "mq", "user"])
    password = random_password.orders_mq.result
  }

  tags = local.common_tags
}
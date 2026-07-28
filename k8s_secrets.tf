# k8s_secrets.tf

resource "kubernetes_secret" "catalog_db" {
  metadata {
    name      = "catalog-db"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  data = {
    endpoint = aws_db_instance.catalog.address
    name     = "catalog"
    username = join("_", ["catalog", "db", "user"])
    password = random_password.catalog_db.result
  }
}

resource "kubernetes_secret" "orders_db" {
  metadata {
    name      = "orders-db"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  data = {
    endpoint = aws_db_instance.orders.address
    name     = "orders"
    username = join("_", ["orders", "db", "user"])
    password = random_password.orders_db_password.result
  }
}

resource "kubernetes_secret" "checkout_redis" {
  metadata {
    name      = "checkout-redis"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  data = {
    endpoint = aws_elasticache_cluster.checkout.cache_nodes[0].address
    port     = "6379"
  }
}

resource "kubernetes_secret" "orders_mq" {
  metadata {
    name      = "orders-mq"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  data = {
    endpoint = aws_mq_broker.orders.instances[0].endpoints[0]
    username = join("_", ["orders", "mq", "user"])
    password = random_password.orders_mq.result
  }
}

resource "kubernetes_secret" "carts_dynamodb" {
  metadata {
    name      = "carts-dynamodb"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  data = {
    table  = aws_dynamodb_table.carts.name
    region = var.aws_region
  }
}
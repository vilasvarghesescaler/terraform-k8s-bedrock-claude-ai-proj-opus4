# variables.tf

# ---- Core ----
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "scaler-eks-cluster"
}

variable "k8s_version" {
  type    = string
  default = "1.36"
}

# ---- Networking ----
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}


variable "app_namespace" {
  type    = string
  default = "retail-store"
}

variable "services" {
  type    = list(string)
  default = ["ui", "catalog", "cart", "checkout", "orders"]
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "catalog_db_id" {
  type    = string
  default = null # defaults to "<cluster>-catalog-mysql" in locals
}
variable "catalog_db_class" {
  type    = string
  default = "db.t3.micro"
}
variable "catalog_db_name" {
  type    = string
  default = "catalog"
}
variable "catalog_db_user" {
  type    = string
  default = "catalog"
}

# ---- Datastore: orders (RDS PostgreSQL) ----
variable "orders_db_id" {
  type    = string
  default = null
}
variable "orders_db_class" {
  type    = string
  default = "db.t3.micro"
}
variable "orders_db_name" {
  type    = string
  default = "orders"
}
variable "orders_db_user" {
  type    = string
  default = "orders"
}

# ---- Datastore: checkout (ElastiCache Redis) ----
variable "checkout_redis_id" {
  type    = string
  default = null
}
variable "checkout_redis_node_type" {
  type    = string
  default = "cache.t3.micro"

  validation {
    condition     = can(regex("^cache\\.", var.checkout_redis_node_type))
    error_message = "checkout_redis_node_type must be a cache node type (e.g. cache.t3.micro)."
  }
}

variable "orders_mq_instance_type" {
  type    = string
  default = "mq.m5.large"
}
variable "orders_mq_engine_version" {
  type    = string
  default = "3.13"
}
variable "orders_mq_user" {
  type    = string
  default = "orders"
}

variable "carts_ddb_table" {
  type    = string
  default = null
}

variable "enable_log_analyzer" {
  type    = bool
  default = true
}

variable "eks_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "bedrock_model_id" {
  type    = string
  default = "global.anthropic.claude-sonnet-4-6"
}

variable "log_analyzer_role_name" {
  type    = string
  default = ""
}
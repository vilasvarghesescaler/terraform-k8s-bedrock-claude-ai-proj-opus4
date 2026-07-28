# aws_rds_sql.tf

resource "random_password" "catalog_db" {
  length  = 20
  special = false
}

data "aws_rds_orderable_db_instance" "catalog_mysql_db" {
  engine                     = "mysql"
  license_model              = "general-public-license"
  storage_type               = "gp3"
  engine_latest_version      = true
  preferred_instance_classes = ["db.t3.micro", "db.t3.small", "db.t3.medium"]
}

resource "aws_db_instance" "catalog" {
  identifier              = join("-", [local.cluster_name, "rds", "mysql", "catalog"])
  engine                  = data.aws_rds_orderable_db_instance.catalog_mysql_db.engine
  engine_version          = data.aws_rds_orderable_db_instance.catalog_mysql_db.engine_version
  instance_class          = data.aws_rds_orderable_db_instance.catalog_mysql_db.instance_class
  storage_type            = data.aws_rds_orderable_db_instance.catalog_mysql_db.storage_type
  allocated_storage       = 20
  db_name                 = "catalog"
  username                = join("_", ["catalog", "db", "user"])
  password                = random_password.catalog_db.result
  db_subnet_group_name    = aws_db_subnet_group.retail_store_db_subnets.name
  vpc_security_group_ids  = [aws_security_group.datastore_sg.id]
  multi_az                = false
  publicly_accessible     = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  apply_immediately       = true
  tags                    = local.common_tags
}
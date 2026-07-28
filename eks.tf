# eks.tf

resource "aws_security_group" "control_plane" {
  name        = join("-", [local.cluster_name, "control", "sg"])
  description = "EKS control plane security group"
  vpc_id      = aws_vpc.retail_store_vpc.id
  tags        = merge(local.common_tags, { Name = join("-", [local.cluster_name, "control", "sg"]) })

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eks_cluster" "scaler_retail_store_cluster" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = local.cluster_version

  enabled_cluster_log_types = var.enable_log_analyzer ? var.eks_log_types : []

  vpc_config {
    subnet_ids         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_group_ids = [aws_security_group.control_plane.id]
  }
  access_config {
    bootstrap_cluster_creator_admin_permissions = true
    authentication_mode                         = "API_AND_CONFIG_MAP"
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_eks]
  tags       = local.common_tags
}

# ---- Managed node group (AL2023) ----
resource "aws_eks_node_group" "scaler_retail_store_node_group" {
  cluster_name    = aws_eks_cluster.scaler_retail_store_cluster.name
  node_group_name = join("-", [local.cluster_name, "ng"])
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  instance_types  = ["t3.medium"]
  ami_type        = "AL2023_x86_64_STANDARD"

  scaling_config {
    min_size     = local.node_min_size
    max_size     = local.node_max_size
    desired_size = local.node_desired_size
  }

  depends_on = [aws_iam_role_policy_attachment.node]
  tags       = local.common_tags
}
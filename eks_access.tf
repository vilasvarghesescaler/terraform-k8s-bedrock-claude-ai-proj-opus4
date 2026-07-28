resource "aws_eks_access_entry" "admin_ec2" {
  cluster_name  = aws_eks_cluster.scaler_retail_store_cluster.name
  principal_arn = aws_iam_role.admin_ec2.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_ec2" {
  cluster_name  = aws_eks_cluster.scaler_retail_store_cluster.name
  principal_arn = aws_iam_role.admin_ec2.arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin_ec2]
}
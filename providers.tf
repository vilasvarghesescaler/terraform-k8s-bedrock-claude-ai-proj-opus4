# providers.tf

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.scaler_retail_store_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.scaler_retail_store_cluster.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.scaler_retail_store_cluster.name, "--region", local.region]
    }
  }
}
provider "kubernetes" {
  host                   = aws_eks_cluster.scaler_retail_store_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.scaler_retail_store_cluster.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.scaler_retail_store_cluster.name, "--region", local.region]
  }
}
provider "kubectl" {
  host                   = aws_eks_cluster.scaler_retail_store_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.scaler_retail_store_cluster.certificate_authority[0].data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.scaler_retail_store_cluster.name, "--region", local.region]
  }
}
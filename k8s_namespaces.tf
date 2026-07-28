# k8s_namespaces.tf

resource "kubernetes_namespace" "app" {
  metadata {
    name = "retail-store"
  }
  depends_on = [aws_eks_cluster.scaler_retail_store_cluster]
}
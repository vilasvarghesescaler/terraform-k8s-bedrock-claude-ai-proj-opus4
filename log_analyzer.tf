# log_analyzer.tf

data "aws_iam_policy_document" "log_analyzer" {
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "logs:DescribeLogGroups",
      "logs:FilterLogEvents",
      "logs:DescribeLogStreams",
      "bedrock:InvokeModel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "log_analyzer" {
  count = var.enable_log_analyzer && var.log_analyzer_role_name != "" ? 1 : 0

  name   = "EKSLogAnalyzerBedrock"
  role   = var.log_analyzer_role_name
  policy = data.aws_iam_policy_document.log_analyzer.json
}
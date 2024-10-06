resource "aws_iam_user" "developer" {
  name = "developer"
}

resource "aws_iam_policy" "developer-eks" {
  name = "AmazonEKSDeveloperPolicy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow"
        "Action" : [
          "eks:DescribeCluster",
          "eks:ListCluster"
        ]
        "Resource" : "*" # This define that for this specific cluster only like this cluster is created for dev only, so this policy will aplicable for this cluster only. 
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "developer-eks" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.developer-eks.arn # we always use this "arn" but we never define it's value because it's and output which is depencing on resource genration and takes as input for attaching with permission. 
}

resource "aws_eks_access_entry" "developer" {
  cluster_name      = aws_eks_cluster.eks.name
  principal_arn     = aws_iam_user.developer.arn
  kubernetes_groups = ["my-viewer"]
}
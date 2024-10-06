data "aws_caller_identity" "current" {} # This data source we use to get the access to the effective Account ID, User ID, and ARN in which Terraform is authorized.

resource "aws_iam_role" "eks_admin" {
  name = "${local.env}-${local.eks_name}-eks-admin"

  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Action" = "sts:AssumeRole"
        "Effect" = "Allow"
        "Principal" = {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" # creating a role and using root as principal. in this way all the user in this aws account get access.
        }
      },
    ]
  })
}

# We are creating the policy for iam role..
resource "aws_iam_policy" "eks_admin" {
  name = "AmazonEKSAdminPolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "eks.amazonaws.com"
                }
            }
        }
    ]
}
POLICY
}

# Attaching the iam policy with i am role. 
resource "aws_iam_role_policy_attachment" "eks_admin" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = aws_iam_policy.eks_admin.arn
}

# Creating the IAM user.
resource "aws_iam_user" "manager" { # we will create the key for this manually. 
  name = "manager"
}

# This policy we are creating for the IAM user "manager"
resource "aws_iam_policy" "eks_assume_admin" {
  name = "AmazonEKSAssumeAdminPolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement":[
        {   
            "Effect" : "Allow",
            "Action" : [
                "sts:AssumeRole"
            ],
            "Resource": "${aws_iam_role.eks_admin.arn}"
        }
    ]    
  }
POLICY
}

# Attaching the IAM user with policy. 
resource "aws_iam_user_policy_attachment" "manager" {
  user       = aws_iam_user.manager.name
  policy_arn = aws_iam_policy.eks_assume_admin.arn

}

# Here we are providing the access entry to manager IAM user. 
resource "aws_eks_access_entry" "manager" {
  cluster_name      = aws_eks_cluster.eks.name # this eks name comes from the eks cluster output.
  principal_arn     = aws_iam_role.eks_admin.arn
  kubernetes_groups = ["my-admin"]
}
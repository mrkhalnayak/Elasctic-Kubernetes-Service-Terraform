
# IAM role for the EKS. 
resource "aws_iam_role" "eks" {
  name = "${local.env}-${local.eks_name}-eks-cluster" # We are using environment and EKS cluster name as a prefix for the IAM  role in case if we create multiple eks-clsuter in same account. 
  # And there is not strict naming standerds in AWS. 

  ## "assume_role_policy" - (Required) Policy that grants an entity permission to assume the role.

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "eks.amazonaws.com"
        }
      }
    ]
  })
}

# This resource we use to attach the policy to IAM role.
resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" ## This arn of policy we will get inside the aws policy section.
  role       = aws_iam_role.eks.name                            # This will get the role information from the above created "aws_iam_role" resource. 
}

# Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
# Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.

# EKS cluster.
resource "aws_eks_cluster" "eks" {
  name     = "${local.env}-${local.eks_name}"
  version  = local.eks_version
  role_arn = aws_iam_role.eks.arn # This will get the value from "Iam role policy attachment" section.

  # This is the networking setting from the VPC information for end point connection for the private and public subnet.
  vpc_config {
    endpoint_private_access = false # Private subnet endpoint will be disabled. 
    endpoint_public_access  = true  # Public subnet endpoint will be enable for public ip in eks. 

    # Subnet id's and it's name.
    subnet_ids = [
      aws_subnet.private_zone1.id,
      aws_subnet.private_zone2.id
    ]
  }

  # This we have configured for authentication. 
  access_config {
    authentication_mode                         = "API" # This authenticate the user by using the "API".
    bootstrap_cluster_creator_admin_permissions = true  # This give the admin access to the user who create the cluster. Because from where the terraform user is creating the eks will help for deploying helm. 
  }

  depends_on = [aws_iam_role_policy_attachment.eks]
}
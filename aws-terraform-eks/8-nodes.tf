# IAM role for nodes.
resource "aws_iam_role" "nodes" {
  name = "${local.env}-${local.eks_name}-eks-nodes" # We are using environment and EKS cluster name as a prefix for the IAM  role in case if we create multiple eks-clsuter in same account. 
  # And there is not strict naming standerds in AWS. 

  ## "assume_role_policy" - (Required) Policy that grants an entity permission to assume the role.
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "ec2.amazonaws.com" # here in service we are creating node group for which we will use ec2, so it will be "ec2:amazonaws.com".
        }
      }
    ]
  })
}

# This policy now includes AssumeRoleForPodIndentity for the Pod Indentity Agent. 
resource "aws_iam_role_policy_attachment" "aws_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

# This policy manage the secondry IP's for the pod through CNI (Container Netwrok Interface)
resource "aws_iam_role_policy_attachment" "aws_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

# This ec2 container registory read only we use for pull our docker images.
resource "aws_iam_role_policy_attachment" "aws_ec2_container_registory_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# EKS node group we are creating for the EKS cluster.
resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.eks.name
  version         = local.eks_version
  node_group_name = "general"
  node_role_arn   = aws_iam_role.nodes.arn

  subnet_ids = [
    aws_subnet.private_zone1.id,
    aws_subnet.private_zone2.id
  ]
  # Compute resource capacity type and machine type. 
  capacity_type  = "ON_DEMAND"
  instance_types = ["t2.medium"]

  # Saclaing configuration of minimum, maximum and desired state of resource.
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  # We cab yse labels in pod affinity and node selectors, there are some built-in labels derived from the node group names, but in practice, when you try to migrate the application
  # from one node group to anothe with the same labels, it's much easier. So i would suggest suing custome labels for affinity. 
  labels = {
    role = "general"
  }

  # depends_on clause to wait untile the IAM role is ready and all the policies are created and attached. 

  depends_on = [
    aws_iam_role_policy_attachment.aws_eks_worker_node_policy,
    aws_iam_role_policy_attachment.aws_ec2_container_registory_read_only,
    aws_iam_role_policy_attachment.aws_eks_cni_policy,
  ]


  # Terraform resources also allows us to ingore certain attributes of the abjects you trying to create. For example when we deploy the cluster autoscaler, it will manage the 
  # desired size property of the auto-scaling group which will confilict with the terraform state. so the ignoring the desired size attriute is the solution after creating it.

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

}
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster" "eks" {
  name       = var.cluster_name
  depends_on = [module.eks]
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com", "ec2.amazonaws.com", "eks-fargate-pods.amazonaws.com", "eks-nodegroup.amazonaws.com", "lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${module.eks.cluster_version}/amazon-linux-2/recommended/release_version"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}


data "aws_security_group" "karpenter_sg" {
  filter {
    name   = "tag:Name"
    values = ["karpenter-demo-node"]
  }

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }
  depends_on = [aws_iam_role.karpenter_controller_role]
}

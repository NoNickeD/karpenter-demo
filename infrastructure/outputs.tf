#-----------------------------------
# General Outputs
#-----------------------------------
output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

#-----------------------------------
# VPC Outputs
#-----------------------------------
output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "intra_subnets" {
  value = module.vpc.intra_subnets
}

output "database_subnets" {
  value = module.vpc.database_subnets
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "gateway_id" {
  value = module.vpc.public_internet_gateway_route_id
}

#-----------------------------------
# EKS Outputs
#-----------------------------------
output "eks_cluster_id" {
  value = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "new_kubecontext_addition_command" {
  value = "aws eks --region ${var.region} update-kubeconfig --name ${var.cluster_name} --profile ${var.profile} --alias ${var.new_kubeconfig_alias}"
}

# If you want to output the region from Terraform
output "region" {
  description = "The AWS region for deployment"
  value       = var.region
}

output "eks_oidc_id" {
  value = replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://oidc.eks.${var.region}.amazonaws.com/id/", "")
}


#-----------------------------------
# Karpenter Outputs
#-----------------------------------
# Retrieve the IAM Role ARN for Karpenter
output "karpenter_service_account_annotation" {
  description = "Karpenter ServiceAccount IAM Role ARN annotation"
  value       = "eks.amazonaws.com/role-arn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterControllerRole-${var.cluster_name}"
}

# Retrieve the EKS Cluster Name
output "karpenter_cluster_name" {
  description = "The EKS cluster name where Karpenter is deployed"
  value       = var.cluster_name
}

# Retrieve the Interruption Queue Name for Karpenter
output "karpenter_interruption_queue" {
  description = "Karpenter Interruption Queue Name"
  value       = "karpenter-cluster-${var.cluster_name}"
}

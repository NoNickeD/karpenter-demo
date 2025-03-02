# -------------- Create SQS Queue --------------
resource "aws_sqs_queue" "karpenter_sqs" {
  name = "karpenter-cluster-${var.cluster_name}"

  # Optional: Enable server-side encryption
  sqs_managed_sse_enabled = true

  tags = merge(local.tags, { Name = "${var.name}-sqs" })
}

# -------------- Create IAM Role for Karpenter --------------
resource "aws_iam_role" "karpenter_controller_role" {
  name = "KarpenterControllerRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://oidc.eks.${var.region}.amazonaws.com/id/", "")}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.eks.${var.region}.amazonaws.com/id/${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://oidc.eks.${var.region}.amazonaws.com/id/", "")}:sub" = "system:serviceaccount:kube-system:karpenter"
        }
      }
    }]
  })
}

# -------------- IAM Policy for Karpenter to Access SQS --------------
resource "aws_iam_policy" "karpenter_sqs_policy" {
  name        = "KarpenterSQSAccess-${var.cluster_name}"
  description = "Allows Karpenter to access SQS queue for interruption handling"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.karpenter_sqs.arn
      }
    ]
  })
}

# -------------- IAM Policy for Karpenter Pricing Policy --------------
resource "aws_iam_policy" "karpenter_pricing_policy" {
  name        = "KarpenterPricingPolicy-${var.cluster_name}"
  description = "Allows Karpenter to use AWS Pricing API"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "pricing:GetProducts"
        ]
        Resource = "*"
      }
    ]
  })
}

# -------------- IAM Role for Karpenter Nodes --------------
resource "aws_iam_role" "karpenter_node_role" {
  name = "KarpenterNodeRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://oidc.eks.${var.region}.amazonaws.com/id/", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "oidc.eks.${var.region}.amazonaws.com/id/${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://oidc.eks.${var.region}.amazonaws.com/id/", "")}:sub" = "system:serviceaccount:kube-system:karpenter"
          }
        }
      }
    ]
  })
}


# -------------- IAM Policy for Karpenter --------------
resource "aws_iam_policy" "karpenter_instance_profile_management" {
  name        = "KarpenterInstanceProfileManagementPolicy-${var.cluster_name}"
  description = "Allows Karpenter to create and manage EC2 instance profiles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "karpenter_custom_eks_access" {
  name = "CustomEKSAccessPolicy"
  role = aws_iam_role.karpenter_node_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "sts:AssumeRole"
        ]
        Resource = "*"
      }
    ]
  })
  depends_on = [aws_iam_role.karpenter_node_role]
}

# -------------- Attach Policies to IAM Roles --------------
resource "aws_iam_role_policy_attachment" "karpenter_sqs_attachment" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_sqs_policy.arn
}

resource "aws_iam_role_policy_attachment" "karpenter_eks_worker" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_ecr_readonly" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_ec2_full" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "karpenter_pricing_attachment" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_pricing_policy.arn
}

resource "aws_iam_role_policy_attachment" "karpenter_instance_profile_mgmt_attach" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_instance_profile_management.arn
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr_readonly" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ec2_full" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_eks_worker" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_instance_profile" "karpenter_instance_profile" {
  name = "KarpenterInstanceProfile-${var.cluster_name}"
  role = aws_iam_role.karpenter_node_role.name
}

# -------------- Ensure Security Group has the Right Tags --------------
resource "aws_ec2_tag" "karpenter_sg_tag" {
  resource_id = data.aws_security_group.karpenter_sg.id
  key         = "karpenter-managed"
  value       = "true"
}




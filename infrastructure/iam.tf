#--------------------------------
# IAM Roles and Policies
#--------------------------------
resource "aws_iam_policy" "eks_full_access" {
  name        = "EKSFullAccessPolicy"
  description = "Full access to EKS Cluster resources"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:*",
          "ec2:*",
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
}

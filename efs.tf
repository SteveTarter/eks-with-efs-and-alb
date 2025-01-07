# Security group for Amazon Elastic File System (EFS)
resource "aws_security_group" "efs" {
  name   = "efs-sg"
  vpc_id = module.vpc.vpc_id

  # Allows NFS traffic to the EFS
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allows all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
}

# Kubernetes ServiceAccount for EFS application
resource "kubectl_manifest" "efs_service_account" {
  yaml_body = <<-EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: efs-app-service-account
  namespace: default
  annotations:
    # Links the ServiceAccount to the IAM role for EFS CSI driver access
    eks.amazonaws.com/role-arn: ${aws_iam_role.efs_csi_driver_role.arn}
EOF
}

# Retrieves the AWS account ID for use in IAM policies
data "aws_caller_identity" "current" {}

# IAM policy document allowing access to EFS
data "aws_iam_policy_document" "efs_access" {
  statement {
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:DescribeMountTargets"
    ]

    # Grants access to all EFS file systems and access points in the account
    resources = [
      "arn:aws:elasticfilesystem:*:${data.aws_caller_identity.current.account_id}:file-system/*",
      "arn:aws:elasticfilesystem:*:${data.aws_caller_identity.current.account_id}:access-point/*"
    ]
  }
}

# IAM policy granting EFS access
resource "aws_iam_policy" "efs_access_policy" {
  name   = "efs-access-policy"
  policy = data.aws_iam_policy_document.efs_access.json
}

# IRSA role for EFS access in Kubernetes
module "efs_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.3.1"

  role_name = "efs-access-role"

  oidc_providers = {
    eks_provider = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:efs-app-service-account"]
    }
  }
}

# Attach the EFS access policy to the IRSA role
resource "aws_iam_role_policy_attachment" "efs_policy_attachment" {
  role       = module.efs_irsa_role.iam_role_name
  policy_arn = aws_iam_policy.efs_access_policy.arn
}


resource "aws_security_group" "efs" {
  name   = "efs-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "kubectl_manifest" "efs_service_account" {
  yaml_body = <<-EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: efs-app-service-account
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.efs_csi_driver_role.arn}
EOF
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "efs_access" {
  statement {
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:DescribeMountTargets"
    ]

    resources = [
      "arn:aws:elasticfilesystem:*:${data.aws_caller_identity.current.account_id}:file-system/*",
      "arn:aws:elasticfilesystem:*:${data.aws_caller_identity.current.account_id}:access-point/*"
    ]
  }
}

resource "aws_iam_policy" "efs_access_policy" {
  name   = "efs-access-policy"
  policy = data.aws_iam_policy_document.efs_access.json
}

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

resource "aws_iam_role_policy_attachment" "efs_policy_attachment" {
  role       = module.efs_irsa_role.iam_role_name
  policy_arn = aws_iam_policy.efs_access_policy.arn
}


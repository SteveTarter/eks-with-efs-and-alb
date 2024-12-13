# Define EFS CSI Driver IAM Policy
resource "aws_iam_policy" "efs_csi_driver_policy" {
  name        = "AmazonEKS_EFS_CSI_DriverPolicy"
  description = "IAM policy for AWS EFS CSI Driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:DeleteAccessPoint"
        ],
        Resource = "*" # Grants permissions for all EFS resources
      }
    ]
  })
}

# Create IAM Role for EFS CSI Driver
resource "aws_iam_role" "efs_csi_driver_role" {
  name               = "AmazonEKS_EFS_CSI_Driver_Role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# Define Assume Role Policy Document
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn] # Links the role to the OIDC provider for the EKS cluster
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider_arn}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"] # Restricts role assumption to the specified service account
    }
  }
}

# Attach the Policy to the Role
resource "aws_iam_role_policy_attachment" "efs_csi_driver_policy_attachment" {
  role       = aws_iam_role.efs_csi_driver_role.name
  policy_arn = aws_iam_policy.efs_csi_driver_policy.arn
}

# Helm Release for EFS CSI Driver
resource "helm_release" "efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  chart      = "aws-efs-csi-driver"
  version    = "2.5.0" # Update to the latest version

  set {
    name  = "controller.serviceAccount.create"
    value = "true" # Ensures the Helm chart creates the service account
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa" # Matches the service account specified in the IAM role
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\.amazonaws\.com/role-arn"
    value = aws_iam_role.efs_csi_driver_role.arn # Associates the role with the service account
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-efs-csi-driver" # Uses the ECR repository for the driver image
  }

  set {
    name  = "region"
    value = var.region # Sets the AWS region for the driver
  }
}


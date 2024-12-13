# IAM policy module to allow EKS cluster description
module "allow_eks_access_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.3.1"

  name          = "allow-eks-access"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster", # Grants permission to describe EKS clusters
        ]
        Effect   = "Allow"
        Resource = "*" # Applies to all resources; refine as needed for security
      },
    ]
  })
}

# IAM role module for EKS administrators
module "eks_admins_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.3.1"

  role_name         = "eks-admin" # Defines the name of the role
  create_role       = true # Ensures the role is created
  role_requires_mfa = false # MFA not required; adjust based on security requirements

  custom_role_policy_arns = [module.allow_eks_access_iam_policy.arn] # Attaches custom policy to the role

  trusted_role_arns = [
    "arn:aws:iam::${module.vpc.vpc_owner_id}:root" # Allows the specified account to assume the role
  ]
}

# IAM user module for user1
module "user1_iam_user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.3.1"

  name                          = "user1" # Name of the IAM user
  create_iam_access_key         = false # Disables access key creation
  create_iam_user_login_profile = false # Disables login profile creation

  force_destroy = true # Deletes user resources without confirmation
}

# IAM policy to allow assuming the EKS admin role
module "allow_assume_eks_admins_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.3.1"

  name          = "allow-assume-eks-admin-iam-role" # Policy name
  create_policy = true # Ensures the policy is created

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole", # Grants permission to assume roles
        ]
        Effect   = "Allow"
        Resource = module.eks_admins_iam_role.iam_role_arn # Restricts action to the EKS admin role
      },
    ]
  })
}

# IAM group for EKS administrators
module "eks_admins_iam_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.3.1"

  name                              = "eks-admin" # Group name
  attach_iam_self_management_policy = false # Prevents users from managing their own IAM policies
  create_group                      = true # Ensures the group is created
  group_users                       = [module.user1_iam_user.iam_user_name] # Adds user1 to the group
  custom_group_policy_arns          = [module.allow_assume_eks_admins_iam_policy.arn] # Attaches custom policy to the group
}

# Add a policy document that grants EFS access permissions to the worker nodes
data "aws_iam_policy_document" "efs_worker_node" {
  statement {
    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets",
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite"
    ]
    resources = [
      "arn:aws:elasticfilesystem:*:${data.aws_caller_identity.current.account_id}:file-system/*"
    ]
  }
}

resource "aws_iam_policy" "efs_worker_node_policy" {
  name   = "EFSWorkerNodePolicy"
  policy = data.aws_iam_policy_document.efs_worker_node.json
}

module "eks_aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "20.31.1"

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = module.eks_admins_iam_role.iam_role_arn
      username = module.eks_admins_iam_role.iam_role_name
      groups   = ["system:masters"]
    },
  ]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.1"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  # Optional
  cluster_endpoint_public_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_group_defaults = {
    disk_size = var.disk_size
  }

  eks_managed_node_groups = {
    nodes = {
      min_size       = 1
      max_size       = 10
      desired_size   = 1

      instance_types = var.node_instance_type

      public_ip      = true
    }
  }

  node_iam_role_additional_policies = {
    EFSWorkerNodePolicy = aws_iam_policy.efs_worker_node_policy.arn
  }

  tags = {
    Environment = var.environment_label
  }
}

locals {
  sg_ids = {
    node    = module.eks.node_security_group_id
    cluster = module.eks.cluster_security_group_id
  }
}

resource "aws_security_group_rule" "allow_all_node_and_cluster_traffic" {
  for_each = local.sg_ids

  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1" # All protocols
  security_group_id        = each.value
  source_security_group_id = each.value
  description              = "Allow all traffic within nodes and between nodes and the cluster"
}

# Ensure egress is unrestricted for nodes
resource "aws_security_group_rule" "allow_all_egress" {
  for_each = local.sg_ids

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"            # All protocols
  cidr_blocks       = ["10.0.0.0/16"] # Restricted to CIDR of cluster-vpc
  security_group_id = each.value
  description       = "Restrict outbound traffic to internal IP ranges"
}


# https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2009
data "aws_eks_cluster" "default" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

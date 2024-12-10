module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.29.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

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

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = module.eks_admins_iam_role.iam_role_arn
      username = module.eks_admins_iam_role.iam_role_name
      groups   = ["system:masters"]
    },
  ]
  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
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
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  # token                  = data.aws_eks_cluster_auth.default.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.id]
    command     = "aws"
  }
}

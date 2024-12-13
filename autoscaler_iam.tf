# Configures an IAM role for the Kubernetes Cluster Autoscaler using a pre-built Terraform module.

module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.3.1"

  role_name                        = "cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [var.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      # This associates the IAM role with a specific namespace and service account in the Kubernetes cluster.
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}


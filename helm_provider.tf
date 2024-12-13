# Configures the Kubernetes provider for use with AWS EKS
kubernetes {
  host                   = data.aws_eks_cluster.default.endpoint # Retrieves the cluster endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data) # Decodes the cluster's CA certificate

  exec {
    api_version = "client.authentication.k8s.io/v1beta1" # Uses a specific API version for authentication
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.id] # Retrieves an authentication token for the EKS cluster
    command     = "aws" # Specifies the AWS CLI for token retrieval
  }
}


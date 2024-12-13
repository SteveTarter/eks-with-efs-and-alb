# Configures the AWS provider for Terraform
provider "aws" {
  region = var.region # Specifies the AWS region to use
}

# Specifies Terraform and provider requirements
terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl" # Source for the Kubernetes provider
      version = ">= 1.14.0" # Ensures compatibility with Kubernetes provider version 1.14.0 or higher
    }
    helm = {
      source  = "hashicorp/helm" # Source for the Helm provider
      version = ">= 2.6.0" # Ensures compatibility with Helm provider version 2.6.0 or higher
    }
  }

  required_version = "~> 1.0" # Locks Terraform to use version 1.x
}


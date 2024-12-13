# Configures the VPC using a Terraform module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws" # Source of the VPC module
  version = "5.8.1" # Specific version of the module to ensure compatibility

  name = "${var.cluster_name}-vpc" # Name of the VPC, incorporating the cluster name
  cidr = "10.0.0.0/16" # CIDR block for the entire VPC

  # Availability zones and subnet configuration
  azs             = slice(data.aws_availability_zones.available.names, 0, 3) # Selects the first three availability zones
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] # CIDR blocks for private subnets
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"] # CIDR blocks for public subnets

  # Tags for subnets to enable Kubernetes integration
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1" # Marks public subnets for use with external load balancers
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1" # Marks private subnets for use with internal load balancers
  }

  # Networking and DNS settings
  enable_nat_gateway   = true # Enables NAT gateway for internet access from private subnets
  single_nat_gateway   = true # Uses a single NAT gateway to save costs
  enable_dns_hostnames = true # Allows DNS hostnames for instances in the VPC
  enable_dns_support   = true # Enables DNS resolution in the VPC

  tags = {
    Environment = var.environment_label # Adds an environment label tag to all VPC resources
  }
}


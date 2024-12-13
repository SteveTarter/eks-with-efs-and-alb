# Environment label used for tagging and identifying resources
variable "environment_label" {
  description = "Cluster type label (e.g. testing, prod, etc.)"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "disk_size" {
  description = "Disk size for EKS nodes"
  type        = number
  default     = 50
}

variable "node_instance_type" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}


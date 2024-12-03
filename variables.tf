variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "gis_tarterware_efs_id" {
  description = "GIS EFS ID"
  type        = string
}

variable "gis_tarterware_efs_arn" {
  description = "GIS EFSARN"
  type        = string
}

variable "mile_weaver_files_efs_id" {
  description = "Mile Weaver Files EFS ID"
  type        = string
}

variable "mile_weaver_files_efs_arn" {
  description = "Mile Weaver Files EFS ARN"
  type        = string
}

variable "mile_weaver_mongodb_efs_id" {
  description = "Mile Weaver MongoDB EFS ID"
  type        = string
}

variable "mile_weaver_mongodb_efs_arn" {
  description = "Mile Weaver MongoDB EFS ARN"
  type        = string
}

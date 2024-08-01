variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "project_owner" {
  description = "Project Owner - Business unit of this workload"
  type        = string
}

variable "project_name" {
  description = "Project Name"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "api_gw_stage" {
  description = "API Gateway Stage (dev, stage, prod)"
  type        = string
  default     = "prod"
}

variable "sftp_name" {
  description = "SFTP Name"
  type        = string
}

variable "use_vpc_endpoint" {
  description = "Deploy SFTP in VPC or Public"
  type        = bool
  default     = false
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
  default     = "sftp-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "sftp_vpc_endpoint_ingress_rules" {
  description = "IP Whitelist in CIDRs for each broker to access SFTP VPC Endpoint"
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "sftp_bucket_name_prefix" {
  description = "SFTP Bucket Name Prefix"
  type        = string
}

variable "sftp_bucket_force_destroy" {
  description = "Force destroy SFTP S3 Bucket upon destruction"
  type        = bool
  default     = false
}

variable "sftp_secretsmanager_secret_name_prefix" {
  description = "SFTP Secrets Manager Secret Name"
  type        = string
}

variable "sftp_users" {
  description = "SFTP User Definition"
  type = map(object({
    username   = string
    password   = string
    public_key = string
    ip_cidrs   = set(string)
  }))
}
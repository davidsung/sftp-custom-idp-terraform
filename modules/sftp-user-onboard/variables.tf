variable "sftp_server_id" {
  description = "SFTP Server ID"
  type        = string
}

variable "sftp_vpce_security_group_id" {
  description = "SFTP VPCe Security Group ID"
  type        = string
  default     = null
}

variable "sftp_vpce_security_group_ingress_rules" {
  description = "List of Security Group Ingress rules to restrict IP address for accessing SFTP service"
  type = map(string)
}

variable "sftp_bucket_arn" {
  description = "SFTP S3 Bucket ARN for Clearing Operation"
  type        = string
}

variable "sftp_bucket_name" {
  description = "SFTP S3 Bucket for Clearing Operation"
  type        = string
}

variable "sftp_user_credentials" {
  description = "SFTP User Credentials"
  type = map(object({
    username   = string
    password   = string
    public_key = string
  }))
}
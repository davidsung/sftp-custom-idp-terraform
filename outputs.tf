output "sftp_server_id" {
  value = module.sftp_custom_idp.sftp_server_id
}

output "sftp_server_endpoint" {
  value = module.sftp_custom_idp.sftp_server_endpoint
}

output "sftp_s3_bucket_name" {
  value = module.sftp_custom_idp.sftp_s3_bucket_name
}

output "sftp_auth_lambda_arn" {
  value = module.sftp_custom_idp.sftp_auth_lambda_arn
}

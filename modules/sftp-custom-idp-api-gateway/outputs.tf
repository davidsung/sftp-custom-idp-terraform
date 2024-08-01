output "sftp_server_id" {
  value = aws_transfer_server.sftp_server.id
}

output "sftp_server_endpoint" {
  value = aws_transfer_server.sftp_server.endpoint
}

output "sftp_vpce_security_group_id" {
  value = var.use_vpc_endpoint ? aws_security_group.sftp_vpce_security_group.id : ""
}

output "sftp_s3_bucket_name" {
  value = aws_s3_bucket.sftp_storage.bucket
}

output "sftp_s3_bucket_arn" {
  value = aws_s3_bucket.sftp_storage.arn
}

output "sftp_auth_lambda_arn" {
  value = aws_lambda_function.get_user_config.arn
}

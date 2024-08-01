output "secrets_manager_secrets" {
  value = {
    for k, v in aws_secretsmanager_secret.sftp_secrets : k => v.id
  }
}
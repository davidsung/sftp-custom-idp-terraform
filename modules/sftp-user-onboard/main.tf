resource "aws_vpc_security_group_ingress_rule" "sftp_vpce_security_group_ingress_rule" {
  for_each    = var.sftp_vpce_security_group_ingress_rules
  description = "Allow SSH/SFTP accesss from CIDR for ${each.key}"

  security_group_id = var.sftp_vpce_security_group_id

  cidr_ipv4   = each.value
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
  tags = {
    Name = "${each.key}-ingress-rule"
  }
}

# Create a Secrets Manager secret for SFTP user credentials
resource "aws_secretsmanager_secret" "sftp_secrets" {
  for_each = var.sftp_user_credentials
  name     = "aws/transfer/${var.sftp_server_id}/${each.value.username}"
}

resource "aws_secretsmanager_secret_version" "sftp_secrets_version" {
  for_each  = var.sftp_user_credentials
  secret_id = aws_secretsmanager_secret.sftp_secrets[each.key].id
  secret_string = jsonencode({
    Username = each.value.username
    Password = each.value.password
    Policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = "s3:ListBucket"
          Effect = "Allow",
          Resource = [
            "${var.sftp_bucket_arn}/$${transfer:UserName}"
          ],
          Condition = {
            StringLike = {
              "s3:prefix" : [
                "${var.sftp_bucket_arn}/$${transfer:UserName}/*",
                "${var.sftp_bucket_arn}/$${transfer:UserName}"
              ]
            }
          }
        },
        {
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetObjectACL"
          ],
          Effect   = "Allow",
          Resource = "${var.sftp_bucket_arn}/$${transfer:UserName}/clearing/outbound/*"
        },
        {
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObjectVersion",
            "s3:DeleteObject",
            "s3:GetObjectVersion",
            "s3:GetObjectACL",
            "s3:PutObjectACL"
          ],
          Effect   = "Allow",
          Resource = "${var.sftp_bucket_arn}/$${transfer:UserName}/clearing/inbound/*"
        }
      ]
    })
    HomeDirectoryDetails = "[{\"Entry\":\"/\",\"Target\":\"/${var.sftp_bucket_name}/${each.value.username}\"}]"
  })
}

resource "aws_s3_object" "inbound" {
  for_each = var.sftp_user_credentials
  bucket   = var.sftp_bucket_name
  key      = "${each.value.username}/clearing/inbound/"
}

resource "aws_s3_object" "outbound" {
  for_each = var.sftp_user_credentials
  bucket   = var.sftp_bucket_name
  key      = "${each.value.username}/clearing/outbound/"
}


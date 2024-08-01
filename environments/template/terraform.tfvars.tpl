aws_region                             = "ap-northeast-1"
project_owner                          = "project-owner-name"
project_name                           = "project-name"
environment                            = "dev"
api_gw_stage                           = "prod"
sftp_name                              = "SFTP Service Name"
use_vpc_endpoint                       = true
vpc_cidr                               = "10.20.0.0/16"
sftp_bucket_name_prefix                = "sftp-bucket-name-prefix"
sftp_bucket_force_destroy              = true
sftp_secretsmanager_secret_name_prefix = "sftp-secretsmanager-secret-name-prefix"

sftp_users = {
  user1 = {
    username   = "user1"
    password   = "MySecurePassword123!"
    public_key = ""
    ip_cidrs   = ["A.B.C.D/32"]
  }
  user2 = {
    username   = "user2"
    password   = "MySecurePassword456!"
    public_key = ""
    ip_cidrs   = ["W.X.Y.Z/30"]
  }
}

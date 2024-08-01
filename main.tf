locals {
  flattened_sftp_users = flatten([
    for username, user in var.sftp_users : [
      for idx, ip in user.ip_cidrs : {
        username = "${user.username}-${idx}"
        ip       = ip
      }
    ]
  ])

  sftp_users_ingress_rules_map = {
    for item in local.flattened_sftp_users :
    item.username => item.ip
  }

  sftp_users_credentials = {
    for idx, user in var.sftp_users : user.username => {
      username   = user.username
      password   = user.password
      public_key = user.public_key
    }
  }
}

module "sftp_custom_idp" {
  source = "./modules/sftp-custom-idp-api-gateway"

  project_owner                          = var.project_owner
  project_name                           = var.project_name
  environment                            = var.environment
  api_gw_stage                           = var.api_gw_stage
  sftp_name                              = var.sftp_name
  use_vpc_endpoint                       = var.use_vpc_endpoint
  vpc_name                               = var.vpc_name
  vpc_cidr                               = var.vpc_cidr
  sftp_bucket_name_prefix                = var.sftp_bucket_name_prefix
  sftp_bucket_force_destroy              = var.sftp_bucket_force_destroy
  sftp_secretsmanager_secret_name_prefix = var.sftp_secretsmanager_secret_name_prefix
}

module "sftp_secrets_manager" {
  source = "./modules/sftp-user-onboard"

  sftp_server_id                         = module.sftp_custom_idp.sftp_server_id
  sftp_bucket_name                       = module.sftp_custom_idp.sftp_s3_bucket_name
  sftp_bucket_arn                        = module.sftp_custom_idp.sftp_s3_bucket_arn
  sftp_vpce_security_group_id            = module.sftp_custom_idp.sftp_vpce_security_group_id
  sftp_vpce_security_group_ingress_rules = local.sftp_users_ingress_rules_map
  sftp_user_credentials                  = local.sftp_users_credentials
}
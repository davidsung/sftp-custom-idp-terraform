# Create VPC if use_vpc_endpoint is true
module "vpc" {
  count  = var.use_vpc_endpoint ? 1 : 0
  source = "terraform-aws-modules/vpc/aws"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.zones.names
  private_subnets = [cidrsubnet(var.vpc_cidr, 3, 0), cidrsubnet(var.vpc_cidr, 3, 1), cidrsubnet(var.vpc_cidr, 3, 2)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 3, 3), cidrsubnet(var.vpc_cidr, 3, 4), cidrsubnet(var.vpc_cidr, 3, 5)]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = true
}

resource "aws_eip" "sftp_eips" {
  count = var.use_vpc_endpoint ? length(module.vpc[0].public_subnets) : 0

  domain = "vpc"
}

resource "aws_security_group" "sftp_vpce_security_group" {
  name        = "sftp-vpce-security-group"
  description = "Security Group for SFTP VPCe"
  vpc_id      = module.vpc[0].vpc_id

  tags = {
    Name = "sftp-vpce-security-group"
  }
}

# Create KMS Key for S3 Bucket Encryption
resource "aws_kms_key" "sftp_storage_key" {
  description             = "This key is used to encrypt sftp bucket objects"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "sftp_storage_key_alias" {
  name          = "alias/${var.project_name}/${var.environment}/sftp/bucket-encryption-key"
  target_key_id = aws_kms_key.sftp_storage_key.id
}

# Create an S3 bucket for SFTP storage
resource "aws_s3_bucket" "sftp_storage" {
  bucket = "${var.sftp_bucket_name_prefix}-${data.aws_caller_identity.current.account_id}"

  force_destroy = var.sftp_bucket_force_destroy
}

resource "aws_s3_bucket_versioning" "sftp_storage_versioning" {
  bucket = aws_s3_bucket.sftp_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sftp_storage_server_side_encryption_configuration" {
  bucket = aws_s3_bucket.sftp_storage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.sftp_storage_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Create an IAM role for the SFTP server
resource "aws_iam_role" "sftp_role" {
  name = "sftp-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })
}

# Attach IAM policy to grant for accessing KMS encrypted S3 bucket
resource "aws_iam_role_policy" "sftp_kms_encrypted_bucket_policy" {
  name = "sftp-kms-encrypted-bucket-policy"
  role = aws_iam_role.sftp_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ],
        Resource = [
          aws_s3_bucket.sftp_storage.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectVersion",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ],
        Resource = [
          "${aws_s3_bucket.sftp_storage.arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.sftp_storage_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sftp_policy_secrets" {
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  role       = aws_iam_role.sftp_role.name
}

resource "aws_iam_role_policy" "sftp_cloudwatch_log" {
  name = "sftp-cloudwatch-log"
  role = aws_iam_role.sftp_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
        ]
        Resource = "*"
      }
    ]
  })
}

# Add a policy to allow invoking the API Gateway
resource "aws_iam_role_policy" "sftp_api_gateway_invoke" {
  name = "sftp-api-gateway-invoke"
  role = aws_iam_role.sftp_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "${aws_api_gateway_rest_api.custom_identity_provider_api.execution_arn}/*"
      }
    ]
  })
}

# Create the SFTP server
resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "API_GATEWAY"
  url                    = "${aws_api_gateway_deployment.api_deployment.invoke_url}${aws_api_gateway_stage.api_stage.stage_name}"
  protocols              = ["SFTP"]
  domain                 = "S3"
  invocation_role        = aws_iam_role.sftp_role.arn

  endpoint_type = var.use_vpc_endpoint ? "VPC" : "PUBLIC"

  dynamic "endpoint_details" {
    for_each = var.use_vpc_endpoint ? ["enabled"] : []
    content {
      address_allocation_ids = aws_eip.sftp_eips[*].id
      security_group_ids     = [aws_security_group.sftp_vpce_security_group.id]
      subnet_ids             = module.vpc[0].public_subnets
      vpc_id                 = module.vpc[0].vpc_id
    }
  }
  logging_role = aws_iam_role.sftp_role.arn

  tags = {
    Name = var.sftp_name
  }
}

resource "aws_iam_role" "api_gateway_cloudwatch_log_role" {
  name = "api-gateway-cloudwatch-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_log_role_policy" {
  name = "api-gateway-cloudwatch-log-role-log"
  role = aws_iam_role.api_gateway_cloudwatch_log_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:DescribeQueries",
          "logs:FilterLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogGroupFields",
          "logs:GetLogRecord",
          "logs:GetQueryResults",
          "logs:PutLogEvents",
          "logs:StartQuery",
          "logs:StopQuery"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_api_gateway_account" "api_gateway_cloudwatch_log" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_log_role.arn
}

# Create API Gateway RESTful for custom authentication
resource "aws_api_gateway_rest_api" "custom_identity_provider_api" {
  name        = "Transfer Custom Identity Provider basic template API"
  description = "API used for GetUserConfig requests"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "servers_resource" {
  rest_api_id = aws_api_gateway_rest_api.custom_identity_provider_api.id
  parent_id   = aws_api_gateway_rest_api.custom_identity_provider_api.root_resource_id
  path_part   = "servers"
}

resource "aws_api_gateway_resource" "server_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.custom_identity_provider_api.id
  parent_id   = aws_api_gateway_resource.servers_resource.id
  path_part   = "{serverId}"
}

resource "aws_api_gateway_resource" "users_resource" {
  rest_api_id = aws_api_gateway_rest_api.custom_identity_provider_api.id
  parent_id   = aws_api_gateway_resource.server_id_resource.id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "user_name_resource" {
  rest_api_id = aws_api_gateway_rest_api.custom_identity_provider_api.id
  parent_id   = aws_api_gateway_resource.users_resource.id
  path_part   = "{username}"
}

resource "aws_api_gateway_resource" "get_user_config_resource" {
  rest_api_id = aws_api_gateway_rest_api.custom_identity_provider_api.id
  parent_id   = aws_api_gateway_resource.user_name_resource.id
  path_part   = "config"
}

resource "aws_api_gateway_method" "get_user_config_method" {
  rest_api_id   = aws_api_gateway_rest_api.custom_identity_provider_api.id
  resource_id   = aws_api_gateway_resource.get_user_config_resource.id
  http_method   = "GET"
  authorization = "AWS_IAM"
  request_parameters = {
    "method.request.header.PasswordBase64" = false
    "method.request.querystring.protocol"  = false
    "method.request.querystring.sourceIp"  = false
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.custom_identity_provider_api.id
  resource_id = aws_api_gateway_resource.get_user_config_resource.id
  status_code = "200"
  response_models = {
    "application/json" = "UserConfigResponseModel"
  }
  http_method = aws_api_gateway_method.get_user_config_method.http_method

  depends_on = [aws_api_gateway_model.get_user_config_response_model]
}


resource "aws_api_gateway_integration" "get_user_config_integration" {
  rest_api_id = aws_api_gateway_rest_api.custom_identity_provider_api.id
  resource_id = aws_api_gateway_resource.get_user_config_resource.id
  http_method = aws_api_gateway_method.get_user_config_method.http_method

  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.get_user_config.invoke_arn

  request_templates = {
    "application/json" = <<EOF
{
  "username": "$util.urlDecode($input.params('username'))",
  "password": "$util.escapeJavaScript($util.base64Decode($input.params('PasswordBase64'))).replaceAll("\\'","'")",
  "protocol": "$input.params('protocol')",
  "serverId": "$input.params('serverId')",
  "sourceIp": "$input.params('sourceIp')"
}
EOF
  }
}

resource "aws_api_gateway_integration_response" "get_user_config_integration_response" {
  http_method = aws_api_gateway_integration.get_user_config_integration.http_method
  resource_id = aws_api_gateway_resource.get_user_config_resource.id
  rest_api_id = aws_api_gateway_rest_api.custom_identity_provider_api.id
  status_code = "200"
}

resource "aws_api_gateway_model" "get_user_config_response_model" {
  name         = "UserConfigResponseModel"
  description  = "API response for GetUserConfig"
  rest_api_id  = aws_api_gateway_rest_api.custom_identity_provider_api.id
  content_type = "application/json"
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "UserUserConfig"
    type      = "object"
    properties = {
      HomeDirectory = {
        type = "string"
      }
      Role = {
        type = "string"
      }
      Policy = {
        type = "string"
      }
      PublicKeys = {
        type = "array"
        items = {
          type = "string"
        }
      }
    }
  })
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [aws_api_gateway_integration.get_user_config_integration]

  rest_api_id = aws_api_gateway_rest_api.custom_identity_provider_api.id
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.custom_identity_provider_api.id
  stage_name    = var.api_gw_stage
}

# Create a Lambda function for custom authentication
resource "aws_lambda_function" "get_user_config" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "get-user-config-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SFTP_ROLE_ARN          = aws_iam_role.sftp_role.arn
      SECRETS_MANAGER_REGION = data.aws_region.current.name
      S3_BUCKET_ARN          = aws_s3_bucket.sftp_storage.arn
      KMS_KEY_ARN            = aws_kms_key.sftp_storage_key.arn
    }
  }
}

# Create a zip file from the Lambda function source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_user_config.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.custom_identity_provider_api.execution_arn}/*/*"
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "sftp-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach necessary policies to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  role       = aws_iam_role.lambda_role.name
}

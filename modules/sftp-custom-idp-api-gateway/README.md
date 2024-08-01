# NADEX CDNA SFTP using AWS Transfer Family SFTP

Brief description of your project.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Modules](#modules)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Resources Created](#resources-created)
- [Notes](#notes)
- [Contributing](#contributing)
- [License](#license)

## Overview

Provide a more detailed explanation of what your project does, its purpose, and any key features.

## Prerequisites

List any prerequisites for using this Terraform project, such as:

- Terraform version
- AWS CLI configured with appropriate credentials
- Any other necessary tools or configurations

## Usage

Explain how to use your Terraform project. For example:

1. Clone the repository
2. Navigate to the project directory
3. Prepare the `terraform.tfvars`
```shell
cp environments/template/terraform.tfvars.tpl environments/dev/terraform.tfvars.tpl
```
4. Initialize Terraform:
```shell
terraform init
```
5. Review the execution plan:
```shell
terraform plan -var-file environments/dev/terraform.tfvars.tpl
```
6. Apply the changes:
```shell
terraform apply -var-file environments/dev/terraform.tfvars.tpl
```
7. Capture the outputs and create the necessary 
```shell
cp environments/template/secrets-terraform.tfvars.tpl ../nadex-sftp-user-onboard-secrets-terraform/environments/dev/terraform.tfvars.tpl
```

## Modules

If your project uses modules, list and briefly describe each one.

## Inputs

List and describe the input variables your project uses. For example:

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `aws_region` | The AWS region to deploy to | `string` | `"us-west-2"` | no |
| `instance_type` | EC2 instance type | `string` | `"t2.micro"` | no |

## Outputs

| Name | Description          |
|------|----------------------|
| `sftp_server_id` | SFTP Server ID       |
| `sftp_server_endpoint` | SFTP Server Endpoint |
| `sftp_s3_bucket_name` | S3 Bucket Name       |
| `sftp_auth_lambda_arn` | Lambda ARN           |

## Test Cases
1. [WIP] Access SFTP custom domain endpoint
4. [WIP] Access SFTP endpoint from a whitelisted source IP
5. [WIP] Access SFTP endpoint from a non-whitelisted source IP
1. Authenticate with username and password
2. Authenticate with incorrect username and incorrect password
3. [WIP] Authenticate with public key
6. 

## Resources Created

List the main AWS resources that this project creates.

## Notes

Session Policy Example:
```json
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "AllowListingOfUserFolder",
          "Action": [
              "s3:ListBucket"
          ],
          "Effect": "Allow",
          "Resource": [
              "arn:aws:s3:::${transfer:HomeBucket}"
          ],
          "Condition": {
              "StringLike": {
                  "s3:prefix": [
                      "${transfer:HomeFolder}/*",
                      "${transfer:HomeFolder}"
                  ]
              }
          }
      },
      {
          "Sid": "HomeDirObjectAccess",
          "Effect": "Allow",
          "Action": [
              "s3:PutObject",
              "s3:GetObject",
              "s3:DeleteObjectVersion",
              "s3:DeleteObject",
              "s3:GetObjectVersion",
              "s3:GetObjectACL",
              "s3:PutObjectACL"
          ],
          "Resource": "arn:aws:s3:::${transfer:HomeDirectory}/*"
       }
  ]
}
```
Restricting user to delete files in outbound folder
```json
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "AllowListingOfUserFolder",
          "Action": [
              "s3:ListBucket"
          ],
          "Effect": "Allow",
          "Resource": [
              "arn:aws:s3:::${transfer:HomeBucket}"
          ],
          "Condition": {
              "StringLike": {
                  "s3:prefix": [
                      "${transfer:HomeFolder}/*",
                      "${transfer:HomeFolder}"
                  ]
              }
          }
      },
      {
          "Sid": "HomeDirObjectAccess",
          "Effect": "Allow",
          "Action": [
              "s3:GetObject",
              "s3:GetObjectVersion",
              "s3:GetObjectACL"
          ],
          "Resource": "arn:aws:s3:::${transfer:HomeDirectory}/clearing/outbound/*"
       },
       {
          "Sid": "HomeDirObjectAccess",
          "Effect": "Allow",
          "Action": [
              "s3:PutObject",
              "s3:GetObject",
              "s3:DeleteObjectVersion",
              "s3:DeleteObject",
              "s3:GetObjectVersion",
              "s3:GetObjectACL",
              "s3:PutObjectACL"
          ],
          "Resource": "arn:aws:s3:::${transfer:HomeDirectory}/clearing/inbound/*"
       }
  ]
}
```
## References
1. [AWS Blog - Use IP whitelisting to secure your AWS Transfer for SFTP servers](https://aws.amazon.com/blogs/storage/use-ip-whitelisting-to-secure-your-aws-transfer-for-sftp-servers/)
2. [AWS Blog - Enable password authentication for AWS Transfer Family using AWS Secrets Manager (updated)](https://aws.amazon.com/blogs/storage/enable-password-authentication-for-aws-transfer-family-using-aws-secrets-manager-updated/)
3. [AWS Blog - Implement multi-factor authentication based managed file transfer using AWS Transfer Family and AWS Secrets Manager](https://aws.amazon.com/blogs/storage/implement-multi-factor-authentication-based-managed-file-transfer-using-aws-transfer-family-and-aws-secrets-manager/)
4. [AWS Blog - Detect malware threats using AWS Transfer Family](https://aws.amazon.com/blogs/storage/detect-malware-threats-using-aws-transfer-family/)

## Contributing

Explain how others can contribute to your project, if applicable.

## License

Specify the license under which your project is released.

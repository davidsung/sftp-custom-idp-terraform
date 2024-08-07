import os
import json
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event))
    resp_data = {}

    if 'S3_BUCKET_ARN' not in os.environ:
        print("S3_BUCKET_ARN environment variable missing  - Unexpected")
        return resp_data

    if 'KMS_KEY_ARN' not in os.environ:
        print("KMS_KEY_ARN environment variable missing  - Unexpected")
        return resp_data

    if 'username' not in event or 'serverId' not in event:
        print("Incoming username or serverId missing  - Unexpected")
        return resp_data

    # It is recommended to verify server ID against some value, this template does not verify server ID
    input_username = event['username']
    input_serverId = event['serverId']
    print("Username: {}, ServerId: {}".format(input_username, input_serverId));

    if 'password' in event:
        input_password = event['password']
        if input_password == '' and (event['protocol'] == 'FTP' or event['protocol'] == 'FTPS'):
            print("Empty password not allowed")
            return resp_data
    else:
        print("No password, checking for SSH public key")
        input_password = ''

    # Lookup user's secret which can contain the password or SSH public keys
    resp = get_secret("aws/transfer/" + input_serverId + "/" + input_username)

    if resp != None:
        resp_dict = json.loads(resp)
    else:
        print("Secrets Manager exception thrown")
        return {}

    if input_password != '':
        if 'Password' in resp_dict:
            resp_password = resp_dict['Password']
        else:
            print("Unable to authenticate user - No field match in Secret for Password")
            return {}

        if 'Username' in resp_dict:
            resp_username = resp_dict['Username']
        else:
            print("Unable to authenticate user - No field match in Secret for Username")
            return {}

        if resp_password != input_password or resp_username != input_username:
            print("Unable to authenticate user - Incoming username and password do not match stored")
            return {}
    else:
        # SSH Public Key Auth Flow - The incoming password was empty so we are trying ssh auth and need to return the public key data if we have it
        if 'PublicKey' in resp_dict:
            resp_data['PublicKeys'] = resp_dict['PublicKey'].split(",")
        else:
            print("Unable to authenticate user - No public keys found")
            return {}

    # If we've got this far then we've either authenticated the user by password or we're using SSH public key auth and
    # we've begun constructing the data response. Check for each key value pair.
    # These are required so set to empty string if missing
    if 'SFTP_ROLE_ARN' in os.environ:
        resp_data['Role'] = os.environ['SFTP_ROLE_ARN']
    else:
        print("No field match for role - Set empty string in response")
        resp_data['Role'] = ''

    resp_data['Policy'] = json.dumps({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowListingOfUserFolder",
                "Effect": "Allow",
                "Action": [
                    "s3:ListBucket",
                ],
                "Resource": f"{os.environ['S3_BUCKET_ARN']}",
                "Condition": {
                    "StringLike": {
                        "s3:prefix": [
                            f"{input_username}/*",
                            f"{input_username}"
                        ]
                    }
                }
            },
            {
                "Sid": "DenyFolderDeletion",
                "Effect": "Deny",
                "Action": [
                    "s3:DeleteObject",
                    "s3:DeleteObjectVersion",
                ],
                "Resource": f"{os.environ['S3_BUCKET_ARN']}/{input_username}/clearing"
            },
            {
                "Sid": "DefaultHomeFolderObjectReadOnlyAccess",
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:GetObjectVersion",
                    "s3:GetObjectACL",
                ],
                "Resource": f"{os.environ['S3_BUCKET_ARN']}/{input_username}/*"
            },
            {
                "Sid": "InboundFolderObjectReadWriteAccess",
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:DeleteObjectVersion",
                    "s3:DeleteObject",
                    "s3:GetObjectVersion",
                    "s3:GetObjectACL",
                    "s3:PutObjectACL",
                ],
                "Resource": f"{os.environ['S3_BUCKET_ARN']}/{input_username}/clearing/inbound/*"
            },
            {
                "Sid": "KMSKeyAccess",
                "Effect": "Allow",
                "Action": [
                    "kms:Encrypt",
                    "kms:Decrypt",
                    "kms:ReEncrypt*",
                    "kms:GenerateDataKey*",
                    "kms:DescribeKey"
                ],
                "Resource": f"{os.environ['KMS_KEY_ARN']}"
            }
        ]
    })

    if 'HomeDirectoryDetails' in resp_dict:
        print("HomeDirectoryDetails found {} - Applying setting for virtual folders".format(resp_dict['HomeDirectoryDetails']))
        resp_data['HomeDirectoryDetails'] = resp_dict['HomeDirectoryDetails']
        resp_data['HomeDirectoryType'] = "LOGICAL"
    elif 'HomeDirectory' in resp_dict:
        print("HomeDirectory found - Cannot be used with HomeDirectoryDetails")
        resp_data['HomeDirectory'] = resp_dict['HomeDirectory']
    else:
        print("HomeDirectory not found - Defaulting to /")

    print("Completed Response Data: "+json.dumps(resp_data))
    return resp_data

def get_secret(id):
    region = os.environ['SECRETS_MANAGER_REGION']
    print("Secrets Manager Region: "+region)

    client = boto3.session.Session().client(service_name='secretsmanager', region_name=region)

    try:
        resp = client.get_secret_value(SecretId=id)
        # Decrypts secret using the associated KMS CMK.
        # Depending on whether the secret is a string or binary, one of these fields will be populated.
        if 'SecretString' in resp:
            print("Found Secret String")
            return resp['SecretString']
        else:
            print("Found Binary Secret")
            return resp['SecretBinary']
    except ClientError as err:
        print('Error Talking to SecretsManager: ' + err.response['Error']['Code'] + ', Message: ' + str(err))
        return None
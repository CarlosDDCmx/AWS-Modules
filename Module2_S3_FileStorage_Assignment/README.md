# AWS S3 File Storage System with Public and Private Access

## Overview
This solution implements a secure file storage system on Amazon S3 with both public and private access configurations. The system includes:
- Publicly accessible files
- Private files requiring authentication
- Secure access via IAM roles and policies
- Temporary access using pre-signed URLs
- Server-side encryption for data security

## Architecture
```
+----------------+       +----------------+       +-----------------+
|                |       |                |       |                 |
|   Public User  +-------+   S3 Bucket    |       |  IAM User/Role  |
| (Web/Mobile)   |       |                |       | (Authenticated) |
|                |       +-------+--------+       |                 |
+----------------+               |                +-------+---------+
                                 |                        |
                                 |                        |
                         +-------v--------+        +------v-------+
                         |                |        |              |
                         |  Public Files  |        | Private Files|
                         |                |        |              |
                         +----------------+        +--------------+
```

## Setup Instructions

### 1. Create S3 Bucket
```bash
aws s3api create-bucket \
  --bucket file-storage-<your-unique-name> \
  --region us-east-1 \
  --create-bucket-configuration LocationConstraint=us-east-1
```

### 2. Enable Versioning
```bash
aws s3api put-bucket-versioning \
  --bucket file-storage-<your-unique-name> \
  --versioning-configuration Status=Enabled
```

### 3. Configure Public Access Settings
```bash
# Block public access by default
aws s3api put-public-access-block \
  --bucket file-storage-<your-unique-name> \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 4. Create Folder Structure
```bash
aws s3api put-object \
  --bucket file-storage-<your-unique-name> \
  --key public/
  
aws s3api put-object \
  --bucket file-storage-<your-unique-name> \
  --key private/
```

### 5. Set Bucket Policy for Public Access
**public-policy.json**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForPublicFolder",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::file-storage-<your-unique-name>/public/*"
    }
  ]
}
```

Apply policy:
```bash
aws s3api put-bucket-policy \
  --bucket file-storage-<your-unique-name> \
  --policy file://public-policy.json
```

### 6. Enable Server-Side Encryption
```bash
aws s3api put-bucket-encryption \
  --bucket file-storage-<your-unique-name> \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'
```

### 7. Create IAM Policy for Private Access
**private-access-policy.json**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::file-storage-<your-unique-name>/private/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::file-storage-<your-unique-name>",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["private/*"]
        }
      }
    }
  ]
}
```

Create policy:
```bash
aws iam create-policy \
  --policy-name S3PrivateAccessPolicy \
  --policy-document file://private-access-policy.json
```

### 8. Create IAM Role for Private Access
```bash
# Create trust policy (trust-policy.json)
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}

# Create role
aws iam create-role \
  --role-name S3PrivateAccessRole \
  --assume-role-policy-document file://trust-policy.json

# Attach policy to role
aws iam attach-role-policy \
  --role-name S3PrivateAccessRole \
  --policy-arn arn:aws:iam::<account-id>:policy/S3PrivateAccessPolicy
```

## Usage Examples

### 1. Upload Files
```bash
# Public file
aws s3 cp public-document.txt s3://file-storage-<your-unique-name>/public/

# Private file
aws s3 cp confidential-document.txt s3://file-storage-<your-unique-name>/private/
```

### 2. Access Public Files
Public URL format:
```
https://file-storage-<your-unique-name>.s3.us-east-1.amazonaws.com/public/public-document.txt
```

### 3. Generate Pre-signed URL for Private Files
```python
import boto3
from datetime import datetime, timedelta

s3 = boto3.client('s3')

# Generate URL valid for 1 hour
url = s3.generate_presigned_url(
    ClientMethod='get_object',
    Params={
        'Bucket': 'file-storage-<your-unique-name>',
        'Key': 'private/confidential-document.txt'
    },
    ExpiresIn=3600
)

print("Temporary access URL:", url)
```

### 4. Access Private Files via IAM Role
```python
import boto3

# Create session using IAM role
session = boto3.Session()
s3 = session.client('s3')

# Download private file
s3.download_file(
    'file-storage-<your-unique-name>',
    'private/confidential-document.txt',
    'local-copy.txt'
)
```

## Security Configuration

### 1. Access Control Matrix
| Access Type        | Public Folder | Private Folder |
|--------------------|---------------|----------------|
| Anonymous Users    | Read          | Denied         |
| IAM Authenticated  | Read          | Read/Write     |
| Pre-signed URLs    | Not Needed    | Temporary Read |
| Bucket Owner       | Full Access   | Full Access    |

### 2. Encryption Methods
1. **SSE-S3 (Default)**:
   - AES-256 encryption
   - Keys managed by S3
   - Enabled by default

2. **SSE-KMS** (Advanced):
```bash
aws s3api put-bucket-encryption \
  --bucket file-storage-<your-unique-name> \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms",
          "KMSMasterKeyID": "<your-kms-key-id>"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'
```

### 3. Access Logging
```bash
# Create logging bucket
aws s3api create-bucket \
  --bucket access-logs-<your-unique-name> \
  --region us-east-1

# Enable logging
aws s3api put-bucket-logging \
  --bucket file-storage-<your-unique-name> \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "access-logs-<your-unique-name>",
      "TargetPrefix": "s3-access-logs/"
    }
  }'
```

## Testing Procedures

### 1. Public Access Test
```bash
# Should succeed
curl https://file-storage-<your-unique-name>.s3.us-east-1.amazonaws.com/public/public-document.txt

# Should fail (403 Forbidden)
curl https://file-storage-<your-unique-name>.s3.us-east-1.amazonaws.com/private/confidential-document.txt
```

### 2. Private Access Test
```bash
# Using AWS CLI with configured credentials
aws s3 ls s3://file-storage-<your-unique-name>/private/

# Without credentials (should fail)
AWS_ACCESS_KEY_ID=invalid AWS_SECRET_ACCESS_KEY=invalid \
  aws s3 ls s3://file-storage-<your-unique-name>/private/
```

### 3. Pre-signed URL Test
1. Generate URL using Python script
2. Access URL within expiration window (should succeed)
3. Access after expiration (should fail with 403)
4. Modify URL parameters (should fail with 403)

## Best Practices

### 1. Security
- **Least Privilege**: Assign minimal required permissions
- **MFA Delete**: Enable for sensitive buckets
```bash
aws s3api put-bucket-versioning \
  --bucket file-storage-<your-unique-name> \
  --versioning-configuration '{
    "Status": "Enabled", 
    "MFADelete": "Enabled"
  }' \
  --mfa "serial-number mfa-code"
```
- **Access Monitoring**: Use CloudTrail for API logging
- **Regular Audits**: Review access policies quarterly

### 2. Cost Optimization
- **Lifecycle Policies**: Automate transitions
```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket file-storage-<your-unique-name> \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "ArchivePrivateFiles",
        "Status": "Enabled",
        "Prefix": "private/",
        "Transitions": [
          {
            "Days": 30,
            "StorageClass": "STANDARD_IA"
          },
          {
            "Days": 90,
            "StorageClass": "GLACIER"
          }
        ]
      }
    ]
  }'
```
- **Storage Classes**: Use appropriate tiers
- **Request Optimization**: Combine small files

### 3. Performance
- **Prefix Optimization**: Use randomized prefixes
- **Transfer Acceleration**: Enable for large files
```bash
aws s3api put-bucket-accelerate-configuration \
  --bucket file-storage-<your-unique-name> \
  --accelerate-configuration '{
    "Status": "Enabled"
  }'
```
- **Caching**: Use CloudFront for frequently accessed files

## Troubleshooting

### 1. Access Denied Errors
- Verify IAM permissions
- Check resource ARNs in policies
- Ensure public access block settings
- Validate bucket policy syntax

### 2. Encryption Issues
- Confirm bucket encryption settings
- Check KMS key policies if using SSE-KMS
- Ensure IAM permissions for encryption operations

### 3. Pre-signed URL Problems
- Verify expiration time (max 7 days)
- Check system time synchronization
- Ensure same credentials used for generation and access
- Validate URL parameters haven't been modified

### 4. Versioning Conflicts
- Check MFA requirements for delete operations
- Verify IAM permissions for version operations
- Use --version-id parameter for specific versions

## Cleanup
```bash
# Empty bucket
aws s3 rm s3://file-storage-<your-unique-name> --recursive

# Delete bucket
aws s3api delete-bucket --bucket file-storage-<your-unique-name>

# Delete IAM role
aws iam detach-role-policy \
  --role-name S3PrivateAccessRole \
  --policy-arn arn:aws:iam::<account-id>:policy/S3PrivateAccessPolicy
  
aws iam delete-role --role-name S3PrivateAccessRole

# Delete IAM policy
aws iam delete-policy \
  --policy-arn arn:aws:iam::<account-id>:policy/S3PrivateAccessPolicy
```
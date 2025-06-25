# Cloud-Based Notes App using AWS S3 and DynamoDB

## Overview
This application is a fully serverless notes management system that leverages AWS services for storage and processing. The solution uses:
- **Amazon S3** for file attachments
- **Amazon DynamoDB** for note metadata and content
- **AWS Lambda** for backend logic
- **API Gateway** for RESTful endpoints
- **JavaScript/HTML/CSS** for the frontend interface

## Setup Instructions

### 1. Create DynamoDB Table
```bash
aws dynamodb create-table \
  --table-name Notes \
  --attribute-definitions AttributeName=NoteID,AttributeType=S \
  --key-schema AttributeName=NoteID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 2. Create S3 Bucket for Attachments
```bash
aws s3api create-bucket \
  --bucket notes-app-attachments-<your-unique-name> \
  --region us-east-1
```

### 3. Create IAM Role for Lambda
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:<account-id>:table/Notes"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::notes-app-attachments-<your-unique-name>/*"
    },
    {
      "Effect": "Allow",
      "Action": "logs:*",
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

### 4. Lambda Functions

There are four Lambda Functions written in NodeJS (Javascript)

1. createNote.js
2. deleteNote.js
3. getAllNotes.js
4. getNote.js

### 5. API Gateway Setup
Create REST API with these endpoints:
```
POST /notes   -> createNote Lambda
GET /notes    -> getAllNotes Lambda
GET /notes/{id} -> getNote Lambda
DELETE /notes/{id} -> deleteNote Lambda
```

## Security Configuration

### 1. S3 Bucket Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<account-id>:role/<lambda-execution-role>"
      },
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::notes-app-attachments-<your-unique-name>/*"
    },
    {
      "Sid": "AllowPublicRead",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::notes-app-attachments-<your-unique-name>/attachments/*"
    }
  ]
}
```

### 2. API Gateway CORS Configuration
Enable CORS for all endpoints with the following settings:
- Access-Control-Allow-Origin: *
- Access-Control-Allow-Methods: GET, POST, DELETE
- Access-Control-Allow-Headers: Content-Type, Authorization

## Testing Instructions

1. **Create a Note**
   - Click "Create Note" button
   - Enter title and content
   - Optionally attach a file
   - Click "Save Note"

2. **View Notes**
   - Notes appear in a grid view
   - Click "View" to see details

3. **View Note Details**
   - Displays full content
   - Shows attachment with download link
   - Provides delete option

4. **Delete a Note**
   - Click "Delete Note" from detail view
   - Confirm deletion
   - Verify note and attachments are removed

## Cleanup

1. Delete S3 Bucket:
```bash
aws s3 rb s3://notes-app-attachments-<your-unique-name> --force
```

2. Delete DynamoDB Table:
```bash
aws dynamodb delete-table --table-name Notes
```

3. Delete API Gateway:
```bash
aws apigateway delete-rest-api --rest-api-id <your-api-id>
```

4. Delete Lambda Functions:
```bash
aws lambda delete-function --function-name createNote
aws lambda delete-function --function-name getAllNotes
aws lambda delete-function --function-name getNote
aws lambda delete-function --function-name deleteNote
```

5. Delete IAM Role:
```bash
aws iam detach-role-policy --role-name NotesAppLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam delete-role --role-name NotesAppLambdaRole
```

# Automated Deployment of a Static Website using AWS CodePipeline

## Overview
This solution automates the deployment of a static website using AWS CodePipeline. The implementation includes:
- **GitHub** as the source repository
- **AWS CodeBuild** for build/test operations
- **Amazon S3** for hosting the static website
- **AWS CodePipeline** for CI/CD orchestration

## Architecture
```
+----------------+     +----------------+     +----------------+     +----------------+
|                |     |                |     |                |     |                |
|   GitHub       +----->  CodePipeline  +----->  CodeBuild     +----->  S3 Bucket    |
|   (Source)     |     |  (Orchestrator)|     |  (Build/Test)  |     |  (Hosting)    |
|                |     |                |     |                |     |                |
+----------------+     +----------------+     +----------------+     +----------------+
```

## Setup Instructions

### 1. Create S3 Bucket for Hosting
```bash
aws s3api create-bucket \
  --bucket static-website-<your-unique-name> \
  --region us-east-1

aws s3 website s3://static-website-<your-unique-name> \
  --index-document index.html \
  --error-document error.html

aws s3api put-bucket-policy \
  --bucket static-website-<your-unique-name> \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "PublicReadGetObject",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::static-website-<your-unique-name>/*"
      }
    ]
  }'
```

### 2. Create GitHub Repository
1. Create a new GitHub repository
2. Add the file found in: Site\index.html

**buildspec.yml**

In Configs\buildspec.yml

### 3. Create IAM Role for CodePipeline

In Cofigs/IAM-Role-CodePipeline.json

### 4. Create CodeBuild Project
```bash
aws codebuild create-project \
  --name StaticWebsiteBuild \
  --source type=GITHUB \
  --source location=https://github.com/carlosDDCmx/AWS-modules.git \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/amazonlinux2-x86_64-standard:5.0 \
  --service-role <your-codebuild-role-arn> \
  --artifacts type=S3,location=static-website-<your-unique-name>,packaging=NONE,overrideArtifactName=true
```

### 5. Create CodePipeline
```bash
aws codepipeline create-pipeline \
  --pipeline-name StaticWebsitePipeline \
  --role-arn <your-codepipeline-role-arn> \
  --pipeline-structure '{
    "name": "StaticWebsitePipeline",
    "roleArn": "<your-codepipeline-role-arn>",
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "Source",
            "actionTypeId": {
              "category": "Source",
              "owner": "ThirdParty",
              "provider": "GitHub",
              "version": "1"
            },
            "runOrder": 1,
            "configuration": {
              "Owner": "<your-username>",
              "Repo": "<your-repo>",
              "Branch": "main",
              "OAuthToken": "<your-github-token>"
            },
            "outputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ]
          }
        ]
      },
      {
        "name": "Build",
        "actions": [
          {
            "name": "Build",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "runOrder": 1,
            "configuration": {
              "ProjectName": "StaticWebsiteBuild"
            },
            "inputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ],
            "outputArtifacts": [
              {
                "name": "BuildOutput"
              }
            ]
          }
        ]
      },
      {
        "name": "Deploy",
        "actions": [
          {
            "name": "Deploy",
            "actionTypeId": {
              "category": "Deploy",
              "owner": "AWS",
              "provider": "S3",
              "version": "1"
            },
            "runOrder": 1,
            "configuration": {
              "BucketName": "static-website-<your-unique-name>",
              "Extract": "true"
            },
            "inputArtifacts": [
              {
                "name": "BuildOutput"
              }
            ]
          }
        ]
      }
    ],
    "artifactStore": {
      "type": "S3",
      "location": "codepipeline-artifacts-<your-unique-name>"
    }
  }'
```

## Pipeline Stages Explained

### 1. Source Stage
- Monitors GitHub repository for changes
- Triggers pipeline on new commits to the main branch
- Downloads source code as artifact

### 2. Build Stage
- Uses AWS CodeBuild to process the application
- Key steps:
  - Installs dependencies (HTML validator)
  - Sets build version based on timestamp
  - Updates version in HTML file
  - Validates HTML structure
  - Prepares artifacts for deployment

### 3. Deploy Stage
- Deploys built artifacts to S3 bucket
- Automatically makes content available via:
  ```
  http://static-website-<your-unique-name>.s3-website-us-east-1.amazonaws.com
  ```

## Testing the Pipeline

1. Make a change to your GitHub repository:
```bash
git clone https://github.com/carlosDDCmx/AWS-modules.git
cd <your-repo>
echo "<p>New feature added!</p>" >> index.html
git add .
git commit -m "Add new feature"
git push origin main
```

2. Monitor pipeline execution:
   - AWS Console > CodePipeline > StaticWebsitePipeline
   - Watch progress through Source > Build > Deploy stages

3. Verify deployment:
   - Visit your S3 website URL
   - Check version number updated to current timestamp
   - Confirm new content appears

## Best Practices

### 1. Security
- Use IAM roles with least privilege
- Store GitHub token in AWS Secrets Manager
- Enable S3 bucket encryption
- Add CloudFront with HTTPS for secure delivery

### 2. Monitoring
- Enable CloudWatch metrics for CodePipeline
- Set up SNS notifications for pipeline events
- Use CloudTrail for API auditing
- Monitor build metrics in CodeBuild

### 3. Optimization
- Add caching to CodeBuild
  ```yaml
  # In buildspec.yml
  cache:
    paths:
      - node_modules/**/*
  ```
- Implement parallel testing
- Use build artifacts for faster deployments
- Set up CloudFront invalidation in deployment stage

### 4. Advanced Validation
Add tests to buildspec.yml:
```yaml
  build:
    commands:
      - echo "Running accessibility tests..."
      - npm install -g pa11y-ci
      - pa11y-ci --sitemap http://example.com/sitemap.xml
      
      - echo "Running performance tests..."
      - npm install -g lighthouse
      - lighthouse http://example.com --output html --output-path ./report.html
```

## Troubleshooting

### Common Issues
1. **Pipeline not triggering**
   - Verify GitHub webhook configuration
   - Check OAuth token permissions
   - Ensure repository branch matches pipeline configuration

2. **Build failures**
   - Check CodeBuild logs for errors
   - Validate buildspec.yml syntax
   - Ensure all dependencies are specified

3. **Deployment issues**
   - Confirm S3 bucket policy allows writes
   - Verify artifact paths are correct
   - Check for sufficient permissions in IAM role

4. **Website not updating**
   - Check CloudFront cache (if used)
   - Verify S3 bucket website configuration
   - Ensure index.html is in root of bucket

## Cleanup
```bash
# Delete S3 buckets
aws s3 rb s3://static-website-<your-unique-name> --force
aws s3 rb s3://codepipeline-artifacts-<your-unique-name> --force

# Delete CodePipeline
aws codepipeline delete-pipeline --name StaticWebsitePipeline

# Delete CodeBuild project
aws codebuild delete-project --name StaticWebsiteBuild

# Delete IAM roles and policies
aws iam detach-role-policy \
  --role-name CodePipelineServiceRole \
  --policy-arn arn:aws:iam::aws:policy/AWSCodePipelineFullAccess
  
aws iam delete-role --role-name CodePipelineServiceRole
```

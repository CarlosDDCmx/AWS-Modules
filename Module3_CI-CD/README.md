# Continuous Deployment System for Node.js Application on AWS EC2

## Overview
This project implements a Continuous Deployment (CD) pipeline that automates the deployment of a Node.js application to AWS EC2 instances using AWS CodePipeline and AWS CodeBuild. The pipeline is triggered by code changes in a GitHub repository, automatically building and deploying the application to EC2 instances.

## Architecture
```
+----------------+     +----------------+     +----------------+     +----------------+
|                |     |                |     |                |     |                |
|   GitHub       +----->  CodePipeline  +----->  CodeBuild     +----->  EC2 Instances |
|   (Source)     |     |  (Orchestrator)|     |  (Build)       |     |  (Deployment)  |
|                |     |                |     |                |     |                |
+----------------+     +-------+--------+     +-------+--------+     +----------------+
                              |                       |
                              |                       |
                      +-------v--------+     +--------v-------+
                      |                |     |                |
                      |  S3 Artifacts  |     |  SNS Alerts    |
                      |                |     |                |
                      +----------------+     +----------------+
```

## Prerequisites
- AWS account with necessary permissions
- GitHub account
- Node.js application (or use the sample provided)

## Setup Instructions

### 1. Create Sample Node.js Application

A simple application is in site\app.js, included also required packages at site\package.json


### 2. Set Up EC2 Instance
1. Launch Amazon Linux 2023 AMI
2. Install prerequisites:
   ```bash
   sudo yum update -y
   sudo yum install -y nodejs
   ```
3. Install and configure CodeDeploy agent:
   ```bash
   sudo yum install -y ruby
   wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
   chmod +x ./install
   sudo ./install auto
   sudo service codedeploy-agent status
   ```

### 3. Create IAM Roles
**EC2 Instance Role:**
- AmazonEC2RoleforAWSCodeDeploy
- AmazonS3ReadOnlyAccess

**CodePipeline Role:**
- AWSCodeDeployFullAccess
- AWSCodeBuildAdminAccess
- AmazonS3FullAccess

### 4. Create CodeDeploy Application
1. Navigate to AWS CodeDeploy
2. Create application:
   - Application name: `NodeAppDeployment`
   - Compute platform: EC2/On-premises
3. Create deployment group:
   - Name: `Production`
   - Service role: `CodeDeployServiceRole`
   - Deployment type: In-place
   - Environment configuration: Amazon EC2 instances
   - Tag group: `Name=CodeDeployInstance`
   - Install agent: Yes

### 5. Add the appspec.yml for Deployment

Location: configs\appspec.yml

### 6. Create Deployment Scripts
**scripts/install_dependencies.sh**
```bash
#!/bin/bash
cd /home/ec2-user/app
npm install
```

**scripts/start_server.sh**
```bash
#!/bin/bash
cd /home/ec2-user/app
source .env
nohup node app.js > app.log 2>&1 &
```

**scripts/stop_server.sh**
```bash
#!/bin/bash
PID=$(pgrep -f "node app.js")
if [[ ! -z "$PID" ]]; then
  kill $PID
fi
```

### 7. Set Up SNS Notifications
```bash
aws sns create-topic --name PipelineNotifications
aws sns subscribe \
  --topic-arn <TOPIC_ARN> \
  --protocol email \
  --notification-endpoint <YOUR_EMAIL>
```

## Pipeline Configuration

### 1. Create CodePipeline
```bash
aws codepipeline create-pipeline --cli-input-json file://pipeline-config.json
```

Then modify the configuration file in configs\pipeline-config.json with your own data such as roleARN, the artifact location and github data.

### 2. Create CodeBuild Project
```bash
aws codebuild create-project --cli-input-json file://build-project.json
```

**build-project.json**
```json
{
  "name": "NodeAppBuild",
  "source": {
    "type": "CODEPIPELINE"
  },
  "artifacts": {
    "type": "CODEPIPELINE"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:5.0",
    "computeType": "BUILD_GENERAL1_SMALL"
  },
  "serviceRole": "<CODEBUILD_ROLE_ARN>"
}
```

## Testing the Pipeline

1. Make a change to your application:
   ```bash
   git clone https://github.com/<your-username>/<your-repo>.git
   cd <repo>
   echo "console.log('Test deployment');" >> app.js
   git add .
   git commit -m "Test deployment"
   git push origin main
   ```

2. Monitor pipeline execution:
   - AWS Console > CodePipeline > NodeAppPipeline
   - Watch progress through Source > Build > Deploy stages

3. Verify deployment:
   - Connect to EC2 instance via SSH:
     ```bash
     ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>
     ```
   - Check running processes:
     ```bash
     ps aux | grep node
     ```
   - View application logs:
     ```bash
     cat /home/ec2-user/app/app.log
     ```
   - Access application:
     ```bash
     curl http://localhost:3000
     ```

## Monitoring and Alerts

1. **Pipeline Status**:
   - Success/failure notifications via SNS
   - Detailed logs in AWS CodePipeline console

2. **Build Logs**:
   - Available in AWS CodeBuild console
   - CloudWatch Logs integration

3. **Deployment Logs**:
   - Available in AWS CodeDeploy console
   - EC2 instance logs at `/var/log/aws/codedeploy-agent/`


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

3. **Deployment failures**
   - Verify CodeDeploy agent is running on EC2
   - Check appspec.yml file paths
   - Validate IAM role permissions
   - Review deployment scripts for errors

4. **Application not starting**
   - Check application logs on EC2
   - Verify port configuration
   - Ensure security groups allow traffic

## Cleanup
```bash
# Delete pipeline
aws codepipeline delete-pipeline --name NodeAppPipeline

# Delete CodeBuild project
aws codebuild delete-project --name NodeAppBuild

# Delete CodeDeploy application
aws deploy delete-application --application-name NodeAppDeployment

# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>

# Delete S3 artifacts bucket
aws s3 rb s3://codepipeline-artifacts-<UNIQUE_NAME> --force

# Delete SNS topic
aws sns delete-topic --topic-arn <TOPIC_ARN>
```

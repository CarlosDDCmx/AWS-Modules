#!/bin/bash
# This script starts the application.

# Navigate to the app directory
cd /home/ec2-user/task-manager-app

# Load environment variables for the deployment
# IMPORTANT: These are placeholders. In a real-world scenario, you would securely 
# fetch these from AWS Secrets Manager or Parameter Store.
export DB_HOST=$(aws ssm get-parameter --name "/task-manager/db-host" --with-decryption --query "Parameter.Value" --output text)
export DB_USER=$(aws ssm get-parameter --name "/task-manager/db-user" --with-decryption --query "Parameter.Value" --output text)
export DB_PASSWORD=$(aws ssm get-parameter --name "/task-manager/db-password" --with-decryption --query "Parameter.Value" --output text)
export DB_NAME="taskdb"
export DB_PORT="5432"
export BACKEND_PORT="5000"
export FRONTEND_PORT="80" # Nginx runs on 80
export REACT_APP_API_URL="/api" # Use relative path for ALB

# Log in to AWS ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

# Pull the latest images from ECR
docker pull $(aws ecr describe-repositories --repository-names task-manager-app/backend --query "repositories[0].repositoryUri" --output text):latest
docker pull $(aws ecr describe-repositories --repository-names task-manager-app/frontend --query "repositories[0].repositoryUri" --output text):latest

# Start the application using Docker Compose
docker-compose -f docker-compose.yml up -d
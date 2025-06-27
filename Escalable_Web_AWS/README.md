# Deploying a Scalable Web Application on AWS

This project demonstrates how to build, deploy, and manage a scalable, fault-tolerant, and secure full-stack web application on Amazon Web Services (AWS). The infrastructure is provisioned using Terraform (Infrastructure as Code), and deployments are fully automated with a CI/CD pipeline using GitHub Actions.

## Table of Contents
1.  [Architecture Overview](#architecture-overview)
2.  [Core Technologies](#core-technologies)
3.  [AWS Services Utilized](#aws-services-utilized)
4.  [Prerequisites](#prerequisites)
5.  [Setup and Deployment Guide](#setup-and-deployment-guide)
    * [Phase 1: Deploy Foundational Infrastructure](#phase-1-deploy-foundational-infrastructure)
    * [Phase 2: Run The Application Locally](#phase-2-run-the-application-locally)
    * [Phase 3: Configure CI/CD Pipeline](#phase-3-configure-cicd-pipeline)
    * [Phase 4: Secure and Distribute the Application](#phase-4-secure-and-distribute-the-application)
6.  [Accessing the Application](#accessing-the-application)
7.  [Cleanup](#cleanup)

---

## Architecture Overview

The application architecture is designed for high availability, scalability, and security, distributing components across public and private subnets in multiple Availability Zones (AZs).

```

```
                           +-------------------------------------------------+
                           |                   User's Browser                |
                           +--------------------------+------------------------+
                                                      |
                                                      | (HTTPS) on yourdomain.com
                                                      v
```

\+---------------------------------------------------------------------------------------------------+
|                                             AWS Cloud                                             |
| +-----------------------------------------------------------------------------------------------+ |
| |                                     AWS CloudFront (CDN)                                        | |
| |  Caches static assets (Frontend) and forwards dynamic requests to the Load Balancer.            | |
| +--+-------------------------------------------------------------------------------------------+--+ |
|    |                                                                                           |    |
|    | (HTTPS)                                                                                   |    |
| +--v-----------------------------------+  +--------------------------------------------------+  |    |
| |          AWS WAF (Firewall)          |  |           AWS Certificate Manager (ACM)          |  |    |
| | Protects against common web exploits.|  |         Provides and manages SSL/TLS cert.       |  |    |
| +------------------+-------------------+  +--------------------------------------------------+  |    |
|                    |                                                                            |
| +------------------v--------------------------------------------------------------------------+ |
| |                                     VPC (10.0.0.0/16)                                         | |
| |                                                                                             | |
| |    +-------------------------------------------+    +-------------------------------------------+ |
| |    |       Public Subnet 1 (AZ 1)              |    |       Public Subnet 2 (AZ 2)              | |
| |    | +---------------------------------------+ |    |                                           | |
| |    | |   Application Load Balancer (ALB)     | |\<---+-------------------------------------------+ |
| |    | +------------------+--------------------+ |    |   Routes traffic based on path:           | |
| |    |                    |                      |    |   - /api/\* -\> Backend TG                  | |
| |    |                    |                      |    |   - /\* -\> Frontend TG                  | |
| |    | +------------------v--------------------+ |    |                                           | |
| |    | | EC2 Instance (Auto Scaling Group)     | |    | +---------------------------------------+ | |
| |    | | +-----------+       +---------------+ | |    | | EC2 Instance (Auto Scaling Group)     | | |
| |    | | | Frontend  |       | Backend       | | |    | | +-----------+       +---------------+ | | |
| |    | | | (Nginx)   |\<------\>| (Node.js API) | | |    | | | Frontend  |       | Backend       | | | |
| |    | | +-----------+       +-------+-------+ | |    | | | (Nginx)   |\<------\>| (Node.js API) | | | |
| |    | +-----------------------------+---------+ |    | | +-----------+       +-------+-------+ | | |
| |    +-------------------------------+-----------+    | +-----------------------------+---------+ | |
| |                                    |                |                               |           | |
| |                                    +----------------+-------------------------------+           | |
| |                                                     |                                          | |
| |    +-------------------------------------------+    |    +-------------------------------------------+ |
| |    |       Private Subnet 1 (AZ 1)             |    |    |       Private Subnet 2 (AZ 2)             | |
| |    |                                           |    |    |                                           | |
| |    | +---------------------------------------+ |    |    | +---------------------------------------+ | |
| |    | |         RDS PostgreSQL DB             | |\<--------\>|       RDS PostgreSQL DB (Standby)     | | |
| |    | |           (Primary)                   | |    |    |                                       | | |
| |    | +---------------------------------------+ |    |    | +---------------------------------------+ | |
| |    +-------------------------------------------+    |    +-------------------------------------------+ |
| |                                                     |                                          | |
| +-----------------------------------------------------+------------------------------------------+ |
|                                                                                                   |
|    +------------------------+      +---------------------------+      +-------------------------+    |
|    |      AWS S3            |      |      AWS ECR              |      |      GitHub -\> CI/CD    |    |
|    | - Stores app assets    |      | - Stores Docker images    |      | - CodePipeline/Deploy   |    |
|    +------------------------+      +---------------------------+      +-------------------------+    |
|                                                                                                   |
\+---------------------------------------------------------------------------------------------------+

````

## Core Technologies

* **Backend:** Node.js, Express.js
* **Frontend:** React.js
* **Database:** PostgreSQL
* **Containerization:** Docker, Docker Compose
* **Infrastructure as Code:** Terraform
* **CI/CD:** GitHub Actions

## AWS Services Utilized

* **Amazon EC2 (Elastic Compute Cloud):** Provides scalable virtual servers to run the containerized frontend and backend applications.
* **EC2 Auto Scaling:** Automatically adjusts the number of EC2 instances based on traffic and CPU load to maintain performance and optimize costs.
* **Amazon S3 (Simple Storage Service):** Used for storing application assets like user uploads and the CloudWatch agent configuration.
* **Amazon RDS (Relational Database Service):** A managed PostgreSQL database with Multi-AZ deployment for high availability and automated backups.
* **Elastic Load Balancing (ELB):** An Application Load Balancer (ALB) distributes incoming traffic across multiple EC2 instances and routes requests based on URL paths.
* **Amazon VPC (Virtual Private Cloud):** Creates a logically isolated section of the AWS Cloud where resources are launched in a secure network.
* **Amazon ECR (Elastic Container Registry):** A fully-managed Docker container registry to store, manage, and deploy our application's Docker images.
* **AWS CodeDeploy:** An automated deployment service that coordinates application deployments to EC2 instances.
* **AWS IAM (Identity and Access Management):** Used to securely manage access to AWS services. The **IAM Role for EC2** grants instances the necessary permissions to access S3, CodeDeploy, and Parameter Store without hardcoding credentials.
* **Amazon CloudWatch:** Monitors the performance of all AWS resources, collects application and system logs, and triggers alarms based on predefined thresholds.
* **AWS Certificate Manager (ACM):** Provisions, manages, and deploys public SSL/TLS certificates for use with ELB and CloudFront.
* **AWS WAF (Web Application Firewall):** Protects the application from common web exploits like SQL injection and cross-site scripting.
* **Amazon CloudFront:** A global Content Delivery Network (CDN) that securely delivers content with low latency and high transfer speeds, caching static assets closer to users.
* **AWS Systems Manager Parameter Store:** Securely stores and manages configuration data and secrets, such as database credentials.

## Prerequisites

Before you begin, ensure you have the following installed and configured:

1.  **AWS Account:** With a registered domain name.
2.  **AWS CLI:** [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
3.  **Terraform:** [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
4.  **Docker & Docker Compose:** [Installation Guide](https://docs.docker.com/get-docker/)
5.  **Git:** [Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

## Setup and Deployment Guide

### Phase 1: Deploy Foundational Infrastructure

This step uses Terraform to provision the core AWS resources (VPC, Subnets, RDS, S3, Security Groups, IAM Roles).

1.  **Clone the Repository:**
    ```bash
    git clone <your-repository-url>
    cd <your-repository-url>
    ```

2.  **Configure AWS Credentials:**
    Ensure your AWS CLI is configured with credentials that have sufficient permissions to create the resources defined.
    ```bash
    aws configure
    ```

3.  **Initialize Terraform:**
    Navigate to the directory containing the `.tf` files and run:
    ```bash
    terraform init
    ```

4.  **Review the Execution Plan:**
    ```bash
    terraform plan
    ```

5.  **Apply the Configuration:**
    This will begin creating the resources in your AWS account.
    ```bash
    terraform apply --auto-approve
    ```

### Phase 2: Run The Application Locally

This step is optional but highly recommended to verify that the application code and Docker setup are working correctly.

1.  **Navigate to the project root.**
2.  **Build and run the containers:**
    ```bash
    docker-compose up --build
    ```
3.  **Access the application:** Open your browser to `http://localhost:3000`.

### Phase 3: Configure CI/CD Pipeline

This phase connects your GitHub repository to your AWS infrastructure for automated deployments.

1.  **Create GitHub Secrets:**
    In your GitHub repository, go to `Settings` > `Secrets and variables` > `Actions` and add the following secrets:
    * `AWS_ACCESS_KEY_ID`: The access key of an IAM user with programmatic access.
    * `AWS_SECRET_ACCESS_KEY`: The secret key for the same IAM user.

2.  **Create SSM Parameters:**
    In the AWS Console, navigate to **Systems Manager > Parameter Store** and create the following three `SecureString` parameters. These are used by the deployment script to securely pass credentials to the backend.
    * `/task-manager/db-host`: The **Endpoint** of your RDS instance (from the Terraform output).
    * `/task-manager/db-user`: Your database username (e.g., `adminuser`).
    * `/task-manager/db-password`: Your database password.

3.  **Update `docker-compose.yml` for Deployment:**
    Modify your `docker-compose.yml` file to pull images from ECR instead of building them. Replace `123456789012` with your AWS Account ID.
    ```yaml
    # In services:backend
    image: [123456789012.dkr.ecr.us-east-1.amazonaws.com/task-manager-app/backend:latest](https://123456789012.dkr.ecr.us-east-1.amazonaws.com/task-manager-app/backend:latest)
    
    # In services:frontend
    image: [123456789012.dkr.ecr.us-east-1.amazonaws.com/task-manager-app/frontend:latest](https://123456789012.dkr.ecr.us-east-1.amazonaws.com/task-manager-app/frontend:latest)
    ```

4.  **Trigger the First Deployment:**
    Commit and push all your changes to the `main` branch. This will trigger the GitHub Actions workflow, which will build and push the Docker images to ECR and deploy the application via CodeDeploy.
    ```bash
    git add .
    git commit -m "Configure for CI/CD"
    git push origin main
    ```

### Phase 4: Secure and Distribute the Application

This final step enables HTTPS, adds a firewall, and configures the CDN.

1.  **Update `variables.tf`:**
    Set the `domain_name` variable in `variables.tf` to your registered domain.

2.  **Apply Final Terraform Changes:**
    Run `terraform apply` again. Terraform will create the CloudFront distribution, WAF, and an ACM certificate. The apply process will pause.

3.  **Validate SSL Certificate:**
    * Terraform will output the details for a `CNAME` record.
    * Go to your domain's DNS provider and add this CNAME record to validate the certificate.
    * Once the record is created, Terraform will automatically detect the validation and complete the provisioning process.

4.  **Point Your Domain to CloudFront:**
    * In the AWS Console, navigate to **CloudFront** and find your new distribution.
    * Copy the **Distribution domain name** (e.g., `d123abcdef.cloudfront.net`).
    * In your DNS provider's settings, create a `CNAME` record for `www` (or an `A` record Alias for the root domain, if supported) that points to the CloudFront domain name.

## Accessing the Application

After DNS propagation (which may take a few minutes to a few hours), you can access your secure, scalable application by navigating to `https://www.your-domain.com`.

## Cleanup

To avoid ongoing charges, you can destroy all the AWS resources created by this project by running:
```bash
terraform destroy --auto-approve
````
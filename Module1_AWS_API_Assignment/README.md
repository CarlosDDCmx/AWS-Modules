# **REST API Deployment with AWS EC2 and Lambda**  

This project demonstrates how to deploy a **REST API** using:  
✅ **AWS EC2** (Flask API)  
✅ **AWS Lambda** (Serverless API)  
✅ **API Gateway** (Public Endpoint)  

## **Prerequisites**  
- An **AWS account** with IAM permissions.  
- **AWS CLI** configured (optional).  
- **Postman** or **cURL** for API testing.  

---

## **Part 1: REST API on EC2**  

### **1. Launch an EC2 Instance**  
- **AMI**: Ubuntu 22.04 LTS  
- **Instance Type**: `t2.micro` (Free Tier)  
- **Security Group**: Allow **SSH (22)** and **HTTP (5000)**  

### **2. Connect via SSH**  
```bash
ssh -i "your-key.pem" ubuntu@<EC2_PUBLIC_IP>
```

### **3. Install Dependencies**  
```bash
sudo apt update
sudo apt install python3 python3-pip -y
pip3 install flask
```

### **4. Create Flask API (`app.py`)**  
```python
from flask import Flask, jsonify
import subprocess

app = Flask(__name__)

@app.route('/hello')
def hello():
    return jsonify(message="Hello, World!")

@app.route('/status')
def status():
    uptime = subprocess.check_output('uptime -p', shell=True).decode('utf-8').strip()
    return jsonify(status="OK", uptime=uptime)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### **5. Run the API**  
```bash
nohup python3 app.py > app.log 2>&1 &
```

### **6. Test the API**  
```bash
curl http://<EC2_PUBLIC_IP>:5000/hello
# {"message":"Hello, World!"}

curl http://<EC2_PUBLIC_IP>:5000/status
# {"status":"OK","uptime":"up 10 minutes"}
```

---

## **Part 2: Serverless API with Lambda & API Gateway**  

### **1. Create Lambda Function**  
- **Runtime**: Python 3.12  
- **IAM Role**: `lambda-basic-execution`  
- **Code (`lambda_function.py`)**  
```python
import json

def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Hello from AWS Lambda!'})
    }
```

### **2. Configure API Gateway**  
- **Create REST API** → **New Resource (`/lambda`)**  
- **Method**: `GET` → **Integration Type**: Lambda  
- **Deploy API** → Stage: `prod`  

### **3. Test the Lambda API**  
```bash
curl https://<API_GATEWAY_ID>.execute-api.<REGION>.amazonaws.com/prod/lambda
# {"message":"Hello from AWS Lambda!"}
```

---

## **Part 3: Security & Monitoring**  

### **1. IAM Roles**  
- **EC2**: Attach `AmazonEC2ReadOnlyAccess`  
- **Lambda**: Ensure `CloudWatchLogsFullAccess`  

### **2. API Gateway Security**  
- Enable **API Key Required** for `GET` method  
- Create **Usage Plan** and **API Key**  

### **3. CloudWatch Monitoring**  
- **EC2**: Install CloudWatch agent to log `app.py`  
- **Lambda**: View logs in `/aws/lambda/<function-name>`  
- **API Gateway**: Monitor latency in `API-Gateway-Execution-Logs`  

---

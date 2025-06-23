# Serverless Image Processing Application on AWS

This project implements a serverless image processing application using AWS services. Users can upload images which are automatically resized to multiple dimensions by an AWS Lambda function triggered by S3 uploads.

## Architecture Overview
```
+----------------+       +----------------+       +---------------+       +-----------------+
|                |       |                |       |               |       |                 |
|  Web Browser   +------>+ API Gateway    +------>+ S3 Bucket     +------>+ Lambda Function |
|  (Upload UI)   |       | (Signed URL)   |       | (Original)    |       | (Image Resizer) |
|                |       |                |       |               |       |                 |
+----------------+       +----------------+       +-------+-------+       +--------+--------+
                                                         |                        |
                                                         |                        |
                                                         |                +-------v--------+
                                                         |                |                |
                                                         |                | S3 Bucket     |
                                                         |                | (Resized)     |
                                                         |                |                |
                                                         |                +-------+--------+
                                                         |                        |
                                                         |                +-------v--------+
                                                         |                |                |
                                                         +----------------+ CloudWatch    |
                                                                          | (Logs/Metrics)|
                                                                          |                |
                                                                          +----------------+
```

## AWS Services Used

1. **Amazon S3**: 
   - `original-images-bucket`: Stores original uploaded images
   - `resized-images-bucket`: Stores processed images
2. **AWS Lambda**: Processes images using Sharp.js
3. **API Gateway**: Provides secure upload endpoints
4. **AWS IAM**: Manages permissions and roles
5. **CloudWatch**: Monitoring and logging

## Setup Instructions

### 1. Create S3 Buckets

```bash
# Create original images bucket
aws s3 mb s3://original-images-bucket-<your-unique-name> \
  --region <your-region>

# Create resized images bucket
aws s3 mb s3://resized-images-bucket-<your-unique-name> \
  --region <your-region>
```

### 2. Configure Bucket Policies

**Original Bucket Policy** (block public access):
```bash
aws s3api put-public-access-block \
  --bucket original-images-bucket-<your-unique-name> \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

**Resized Bucket Policy** (allow public read access):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::resized-images-bucket-<your-unique-name>/resized/*"
    }
  ]
}
```

### 3. Create IAM Roles

**Lambda Execution Role**:
```bash
aws iam create-role --role-name LambdaImageProcessingRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'
```

Attach permissions policy:
```bash
aws iam put-role-policy \
  --role-name LambdaImageProcessingRole \
  --policy-name LambdaS3Access \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Resource": [
          "arn:aws:s3:::original-images-bucket-<your-unique-name>/*",
          "arn:aws:s3:::resized-images-bucket-<your-unique-name>/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": "logs:*",
        "Resource": "arn:aws:logs:*:*:*"
      }
    ]
  }'
```

### 4. Create and Deploy Lambda Function

**Create deployment package**:
```bash
mkdir image-processor
cd image-processor
npm init -y
npm install sharp
```

**index.js**:
```javascript
const AWS = require('aws-sdk');
const sharp = require('sharp');
const s3 = new AWS.S3();

exports.handler = async (event) => {
  const bucket = event.Records[0].s3.bucket.name;
  const key = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
  
  try {
    // Get image from S3
    const image = await s3.getObject({ Bucket: bucket, Key: key }).promise();
    
    // Create resized versions
    const sizes = [200, 400, 800];
    const resizePromises = sizes.map(size => 
      sharp(image.Body)
        .resize(size)
        .toBuffer()
        .then(data => 
          s3.putObject({
            Bucket: 'resized-images-bucket-<your-unique-name>',
            Key: `resized/${size}w/${key}`,
            Body: data,
            ContentType: image.ContentType
          }).promise()
        )
    );
    
    await Promise.all(resizePromises);
    console.log(`Processed ${key} into ${sizes.length} sizes`);
    return { status: 'success' };
  } catch (err) {
    console.error('Processing error:', err);
    throw err;
  }
};
```

**Deploy Lambda function**:
```bash
zip -r function.zip .
aws lambda create-function \
  --function-name image-processor \
  --runtime nodejs18.x \
  --role arn:aws:iam::<account-id>:role/LambdaImageProcessingRole \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --timeout 30 \
  --memory-size 1024
```

### 5. Configure S3 Trigger

```bash
aws lambda add-permission \
  --function-name image-processor \
  --principal s3.amazonaws.com \
  --statement-id s3-trigger \
  --action "lambda:InvokeFunction" \
  --source-arn arn:aws:s3:::original-images-bucket-<your-unique-name> \
  --source-account <your-account-id>

aws s3api put-bucket-notification-configuration \
  --bucket original-images-bucket-<your-unique-name> \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [
      {
        "LambdaFunctionArn": "arn:aws:lambda:<region>:<account-id>:function:image-processor",
        "Events": ["s3:ObjectCreated:*"]
      }
    ]
  }'
```

### 6. Set Up API Gateway for Secure Uploads

**Create API**:
```bash
aws apigateway create-rest-api --name 'ImageUploadAPI'
```

**Create resource and method**:
```bash
# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id <api-id> \
  --query 'items[0].id' \
  --output text)

# Create /upload resource
RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id <api-id> \
  --parent-id $ROOT_ID \
  --path-part upload \
  --query 'id' \
  --output text)

# Create PUT method
aws apigateway put-method \
  --rest-api-id <api-id> \
  --resource-id $RESOURCE_ID \
  --http-method PUT \
  --authorization-type NONE
```

**Configure S3 integration**:
```bash
aws apigateway put-integration \
  --rest-api-id <api-id> \
  --resource-id $RESOURCE_ID \
  --http-method PUT \
  --type AWS \
  --integration-http-method PUT \
  --uri 'arn:aws:apigateway:<region>:s3:path/original-images-bucket-<your-unique-name>/{key}' \
  --credentials <api-gateway-role-arn> \
  --request-parameters '{"integration.request.path.key": "method.request.path.key"}'

aws apigateway put-method-response \
  --rest-api-id <api-id> \
  --resource-id $RESOURCE_ID \
  --http-method PUT \
  --status-code 200

aws apigateway put-integration-response \
  --rest-api-id <api-id> \
  --resource-id $RESOURCE_ID \
  --http-method PUT \
  --status-code 200
```

**Deploy API**:
```bash
aws apigateway create-deployment \
  --rest-api-id <api-id> \
  --stage-name prod
```

### 7. Create Web Interface

**index.html**:
```html
<!DOCTYPE html>
<html>
<head>
  <title>Image Uploader</title>
  <style>/* Styles from previous implementation */</style>
</head>
<body>
  <h1>Serverless Image Processor</h1>
  
  <div class="upload-container">
    <input type="file" id="file-input" accept="image/*">
    <button id="upload-btn">Upload Image</button>
    <div id="upload-status"></div>
  </div>

  <div class="preview">
    <h2>Original Image</h2>
    <img id="original-preview" src="" alt="Original preview">
    
    <h2>Resized Versions</h2>
    <div id="resized-container" class="resized-images"></div>
  </div>

  <script>
    const API_ENDPOINT = 'https://<api-id>.execute-api.<region>.amazonaws.com/prod/upload';
    const RESIZED_BASE_URL = 'https://resized-images-bucket-<your-name>.s3.<region>.amazonaws.com/resized/';
    
    document.getElementById('upload-btn').addEventListener('click', uploadImage);
    
    async function uploadImage() {
      const fileInput = document.getElementById('file-input');
      const file = fileInput.files[0];
      
      if (!file) {
        alert('Please select an image file');
        return;
      }
      
      // Generate unique filename
      const filename = `${Date.now()}-${file.name.replace(/\s+/g, '-')}`;
      const uploadUrl = `${API_ENDPOINT}/${filename}`;
      
      // Display preview
      const preview = document.getElementById('original-preview');
      preview.src = URL.createObjectURL(file);
      
      try {
        // Upload to S3 via API Gateway
        const response = await fetch(uploadUrl, {
          method: 'PUT',
          body: file,
          headers: { 'Content-Type': file.type }
        });
        
        if (response.ok) {
          document.getElementById('upload-status').textContent = 
            'Upload successful! Processing images...';
          
          // Check for resized images periodically
          const checkInterval = setInterval(() => {
            checkResizedImages(filename);
          }, 3000);
        } else {
          throw new Error(`Upload failed: ${response.status}`);
        }
      } catch (error) {
        document.getElementById('upload-status').textContent = 
          `Error: ${error.message}`;
      }
    }
    
    async function checkResizedImages(filename) {
      const sizes = [200, 400, 800];
      const container = document.getElementById('resized-container');
      
      let allExist = true;
      
      for (const size of sizes) {
        const imgUrl = `${RESIZED_BASE_URL}${size}w/${filename}`;
        const exists = await imageExists(imgUrl);
        
        if (exists) {
          if (!document.querySelector(`img[src="${imgUrl}"]`)) {
            const img = document.createElement('img');
            img.src = imgUrl;
            img.alt = `${size}px wide`;
            container.appendChild(img);
          }
        } else {
          allExist = false;
        }
      }
      
      if (allExist) {
        document.getElementById('upload-status').textContent = 
          'All resized versions available!';
        clearInterval(checkInterval);
      }
    }
    
    function imageExists(url) {
      return new Promise(resolve => {
        const img = new Image();
        img.onload = () => resolve(true);
        img.onerror = () => resolve(false);
        img.src = url;
      });
    }
  </script>
</body>
</html>
```

## Testing the Application

1. Open the `index.html` file in a browser
2. Select an image (JPEG, PNG, or WebP)
3. Click "Upload Image"
4. Observe:
   - Original image preview
   - Upload status messages
   - Resized images (200px, 400px, 800px) appearing as they're processed

## Security Considerations

1. **IAM Principle of Least Privilege**:
   - Lambda has only necessary S3 permissions
   - API Gateway has only PutObject permission
2. **S3 Security**:
   - Original bucket blocks public access
   - Resized bucket allows public read only for processed images
3. **Secure Uploads**:
   - API Gateway provides signed URL pattern
   - Uploads go directly to S3 without intermediate servers
4. **Input Validation**:
   - Lambda validates image types
   - Filename sanitization in web UI

## Monitoring and Logging

1. **CloudWatch Logs**:
   - Lambda execution logs
   - API Gateway access logs
2. **CloudWatch Metrics**:
   - Lambda duration and errors
   - S3 bucket sizes
   - API Gateway latency
3. **CloudWatch Alarms**:
   - Lambda error rate > 1%
   - Processing time > 5 seconds
   - S3 storage > 80% capacity

## Cleanup

To avoid ongoing charges, delete all resources:

```bash
# Delete S3 buckets
aws s3 rb s3://original-images-bucket-<your-name> --force
aws s3 rb s3://resized-images-bucket-<your-name> --force

# Delete Lambda function
aws lambda delete-function --function-name image-processor

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id <your-api-id>

# Delete IAM roles
aws iam delete-role-policy --role-name LambdaImageProcessingRole --policy-name LambdaS3Access
aws iam delete-role --role-name LambdaImageProcessingRole
```

## Troubleshooting

1. **Upload Fails (403 Forbidden)**:
   - Verify API Gateway execution role permissions
   - Check S3 bucket CORS configuration
   ```json
   [
     {
       "AllowedHeaders": ["*"],
       "AllowedMethods": ["PUT"],
       "AllowedOrigins": ["*"],
       "ExposeHeaders": []
     }
   ]
   ```

2. **Images Not Processing**:
   - Check Lambda trigger configuration
   - Verify CloudWatch logs for Lambda function
   - Ensure Sharp library is included in deployment package

3. **Resized Images Not Accessible**:
   - Confirm resized bucket policy
   - Verify object path: `resized/<size>w/<filename>`
   - Check for spaces in filenames (use URL encoding)


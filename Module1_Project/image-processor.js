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
            Bucket: 'resized-images-bucket-<your-name>',
            Key: `resized/${size}w/${key}`,
            Body: data,
            ContentType: image.ContentType
          }).promise()
        )
    );
    
    await Promise.all(resizePromises);
    return { status: 'Image processed successfully' };
  } catch (err) {
    console.error(err);
    throw new Error('Image processing failed');
  }
};
const AWS = require('aws-sdk');
const uuid = require('uuid');
const s3 = new AWS.S3();
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const { title, content, fileName, fileData } = JSON.parse(event.body);
  const noteID = uuid.v4();
  const createdAt = new Date().toISOString();
  
  let fileURL = null;
  
  // Upload file if provided
  if (fileName && fileData) {
    const buffer = Buffer.from(fileData, 'base64');
    const key = `attachments/${noteID}/${fileName}`;
    
    await s3.putObject({
      Bucket: process.env.ATTACHMENTS_BUCKET,
      Key: key,
      Body: buffer,
      ContentType: event.headers['Content-Type'] || 'application/octet-stream'
    }).promise();
    
    fileURL = `https://${process.env.ATTACHMENTS_BUCKET}.s3.amazonaws.com/${key}`;
  }
  
  // Save to DynamoDB
  await dynamodb.put({
    TableName: process.env.NOTES_TABLE,
    Item: { NoteID: noteID, Title: title, Content: content, CreatedAt: createdAt, FileURL: fileURL }
  }).promise();
  
  return {
    statusCode: 201,
    body: JSON.stringify({ NoteID: noteID, message: 'Note created successfully' })
  };
};
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3();

exports.handler = async (event) => {
  const noteID = event.pathParameters.id;
  
  // Get note to check for attachments
  const note = await dynamodb.get({
    TableName: process.env.NOTES_TABLE,
    Key: { NoteID: noteID }
  }).promise();
  
  // Delete attachment if exists
  if (note.Item && note.Item.FileURL) {
    const url = new URL(note.Item.FileURL);
    const key = decodeURIComponent(url.pathname.substring(1));
    
    await s3.deleteObject({
      Bucket: process.env.ATTACHMENTS_BUCKET,
      Key: key
    }).promise();
  }
  
  // Delete from DynamoDB
  await dynamodb.delete({
    TableName: process.env.NOTES_TABLE,
    Key: { NoteID: noteID }
  }).promise();
  
  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'Note deleted successfully' })
  };
};
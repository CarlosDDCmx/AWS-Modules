const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const noteID = event.pathParameters.id;
  
  const result = await dynamodb.get({
    TableName: process.env.NOTES_TABLE,
    Key: { NoteID: noteID }
  }).promise();
  
  if (!result.Item) {
    return {
      statusCode: 404,
      body: JSON.stringify({ message: 'Note not found' })
    };
  }
  
  return {
    statusCode: 200,
    body: JSON.stringify(result.Item)
  };
};
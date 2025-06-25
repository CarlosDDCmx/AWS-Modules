const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async () => {
  const result = await dynamodb.scan({
    TableName: process.env.NOTES_TABLE
  }).promise();
  
  return {
    statusCode: 200,
    body: JSON.stringify(result.Items)
  };
};
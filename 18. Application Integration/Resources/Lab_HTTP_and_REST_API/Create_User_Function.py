import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('UsersTable')  # Exact name you created

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        user_id = body['userId']
        name = body['name']
        email = body['email']
        
        table.put_item(
            Item={
                'userId': user_id,
                'name': name,
                'email': email
            }
        )
        
        return {
            'statusCode': 201,
            'body': json.dumps({'message': 'User created successfully'})
        }
    
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
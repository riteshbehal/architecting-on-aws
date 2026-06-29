import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('UsersTable')

def lambda_handler(event, context):
    user_id = event['pathParameters']['userId']
    
    try:
        table.delete_item(Key={'userId': user_id})
        return {
            'statusCode': 200,
            'body': json.dumps({'message': f'User {user_id} deleted successfully'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
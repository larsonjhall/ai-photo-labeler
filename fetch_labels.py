import boto3
import json
from decimal import Decimal

# Initialize resources outside the handler for better performance (Warm Starts)
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ImageAnalysisResults')

# Helper to handle DynamoDB numbers (Decimals) which standard JSON can't read
def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError

def lambda_handler(event, context):
    # 1. Log the event so you can see exactly what API Gateway sends in CloudWatch
    print(f"Full Event: {json.dumps(event)}")

    # 2. Defensive check for empty events
    if event is None:
        return {"statusCode": 500, "body": json.dumps("Error: Event object is None")}

    # 3. Safely grab the image name from the URL (?image=filename.jpg)
    query_params = event.get('queryStringParameters') or {}
    image_id = query_params.get('image')
    
    if not image_id:
        return {
            "statusCode": 400, 
            "body": json.dumps("Missing 'image' parameter in URL.")
        }

    try:
        # 4. Fetch the data from DynamoDB
        response = table.get_item(Key={'ImageId': image_id})
        item = response.get('Item')

        if not item:
            return {
                "statusCode": 404, 
                "body": json.dumps(f"Image '{image_id}' not found in database.")
            }

        # 5. Return the successful response
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*" # Required for your website
            },
            "body": json.dumps(item, default=decimal_default)
        }

    except Exception as e:
        print(f"Database Error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps(f"Internal Database Error: {str(e)}")
        }
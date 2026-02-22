import boto3
import base64
import json
import os

s3 = boto3.client('s3', region_name='us-east-1')
# Use the bucket name from your previous errors
BUCKET_NAME = "my-ai-image-uploads-7528ad4d" 

def lambda_handler(event, context):
    try:
        # 1. Parse the incoming JSON body
        body = json.loads(event['body'])
        file_name = body['file_name']
        image_base64 = body['image_base64']
        
        # 2. Decode the Base64 string back into binary image data
        image_binary = base64.b64decode(image_base64)
        
        # 3. Upload directly to S3
        s3.put_object(
            Bucket="my-ai-image-uploads-4685786b",
            Key=file_name,
            Body=image_binary,
            ContentType='image/jpeg'
        )
        
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "POST, OPTIONS"
            },
            "body": json.dumps({"message": "Successfully uploaded to S3!"})
        }
    except Exception as e:
        print(e)
        return {
            "statusCode": 500,
            "headers": { "Access-Control-Allow-Origin": "*" },
            "body": json.dumps({"error": str(e)})
        }
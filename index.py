import boto3
import json
import time # Import time for the delay

rekognition = boto3.client('rekognition')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ImageAnalysisResults')

def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    # Use unquote to fix potential space/special character issues
    from urllib.parse import unquote_plus
    key = unquote_plus(event['Records'][0]['s3']['object']['key'])

    # 1. Give S3 a moment to breathe (Fixes the Metadata error)
    time.sleep(2) 

    try:
        # 2. Ask the AI what it sees
        response = rekognition.detect_labels(
            Image={'S3Object': {'Bucket': bucket, 'Name': key}},
            MaxLabels=5
        )

        labels = [label['Name'] for label in response['Labels']]
        
        # 3. Save to DynamoDB
        table.put_item(Item={
            'ImageId': key,
            'Labels': labels,
            'Confidence': str(response['Labels'][0]['Confidence'])
        })
        return {"status": "success"}

    except Exception as e:
        print(f"Error processing {key}: {str(e)}")
        raise e
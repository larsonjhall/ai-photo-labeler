import json
import boto3
import os
import uuid
import time
from datetime import datetime

# Initialize clients outside the handler for better performance
transcribe = boto3.client('transcribe')
comprehend = boto3.client('comprehend')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TranscriptionMetadata')

def lambda_handler(event, context):
    print("FULL EVENT RECEIVED:", json.dumps(event))
    output_bucket = os.environ.get('OUTPUT_BUCKET')

    if 'Records' not in event:
        return { 'status': 'ignored', 'reason': 'No Records key found' }

    try:
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        if key.endswith('/'):
            return { 'status': 'ignored', 'reason': 'Folder creation' }

        # 1. Start Transcription
        job_name = f"Job-{uuid.uuid4().hex}"
        file_uri = f"s3://{bucket}/{key}"
        
        transcribe.start_transcription_job(
            TranscriptionJobName=job_name,
            Media={'MediaFileUri': file_uri},
            MediaFormat=key.split('.')[-1],
            LanguageCode='en-US',
            OutputBucketName=output_bucket
        )
        
        # 2. WAIT for the job to finish (Polling)
        print(f"Waiting for job {job_name}...")
        while True:
            status = transcribe.get_transcription_job(TranscriptionJobName=job_name)
            if status['TranscriptionJob']['TranscriptionJobStatus'] in ['COMPLETED', 'FAILED']:
                break
            time.sleep(5) # Check every 5 seconds

        if status['TranscriptionJob']['TranscriptionJobStatus'] == 'COMPLETED':
            # 3. Get the Transcript Text
            transcript_url = status['TranscriptionJob']['Transcript']['TranscriptFileUri']
            # Note: Since we saved to S3, we need to fetch the JSON result from S3
            s3_client = boto3.client('s3')
            result = s3_client.get_object(Bucket=output_bucket, Key=f"{job_name}.json")
            data = json.loads(result['Body'].read().decode('utf-8'))
            transcript_text = data['results']['transcripts'][0]['transcript']

            # 4. Analyze Sentiment
            sentiment_data = comprehend.detect_sentiment(Text=transcript_text, LanguageCode='en')
            sentiment = sentiment_data['Sentiment']

            # 5. Save to DynamoDB
            table.put_item(
                Item={
                    'TranscriptId': job_name,
                    'Text': transcript_text,
                    'Sentiment': sentiment,
                    'Timestamp': str(datetime.now())
                }
            )
            print(f"Success! Data saved for {job_name}")
            return {'status': 'success'}

    except Exception as e:
        print(f"Error: {str(e)}")
        raise e
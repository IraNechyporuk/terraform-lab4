import json
import boto3
import os
from datetime import datetime

sqs = boto3.client('sqs')
QUEUE_URL = os.environ.get('QUEUE_URL')


def handler(event, context):
    """Приймає POST /telemetry з тілом {"device_id": "1", "temperature": 23.5}"""
    try:
        # HTTP API Gateway v2 передає метод інакше, ніж REST API
        request_context = event.get('requestContext', {})
        http_method = (
            request_context.get('http', {}).get('method')      # HTTP API v2
            or request_context.get('httpMethod', '')            # REST API fallback
        )

        if http_method != 'POST':
            return {
                'statusCode': 405,
                'body': json.dumps({'error': 'Method Not Allowed'}),
            }

        body = json.loads(event.get('body') or '{}')
        device_id   = body.get('device_id')
        temperature = body.get('temperature')

        if not device_id or temperature is None:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'device_id and temperature are required'}),
            }

        message = {
            'device_id':   str(device_id),
            'temperature': float(temperature),
            'timestamp':   datetime.utcnow().isoformat() + 'Z',
        }

        response = sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message),
        )

        return {
            'statusCode': 202,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'status':      'queued',
                'message_id':  response['MessageId'],
                'device_id':   device_id,
                'temperature': temperature,
            }),
        }

    except Exception as e:
        print(f'Error in api_handler: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal Server Error'}),
        }
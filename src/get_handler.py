import json
import boto3
import os
from boto3.dynamodb.conditions import Key
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('TABLE_NAME')
table = dynamodb.Table(TABLE_NAME)


def _decimal_default(obj):
    """JSON-серіалізатор для Decimal (DynamoDB повертає Decimal, не float)."""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError


def handler(event, context):
    """Обробляє GET /telemetry/{device_id}/latest

    ВИПРАВЛЕННЯ: тепер читає total_sum та sample_count і рахує avg = total_sum / sample_count,
    а не покладається на поле avg_temperature, якого більше немає.
    """
    try:
        path_params = event.get('pathParameters') or {}
        device_id = path_params.get('device_id')

        if not device_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'device_id required'}),
            }

        # Останній запис по device_id (ScanIndexForward=False → DESC по sort key)
        response = table.query(
            KeyConditionExpression=Key('device_id').eq(device_id),
            ScanIndexForward=False,
            Limit=1,
        )

        items = response.get('Items', [])
        if not items:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'No data found for this device'}),
            }

        latest = items[0]

        total_sum    = Decimal(str(latest.get('total_sum', 0)))
        sample_count = int(latest.get('sample_count', 0))

        if sample_count == 0:
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'sample_count is zero — corrupted record'}),
            }

        avg_temp = round(float(total_sum / sample_count), 2)

        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'device_id':    latest['device_id'],
                'window_start': latest['window_start'],
                'avg_temp':     avg_temp,
                'total_sum':    float(total_sum),
                'sample_count': sample_count,
                'updated_at':   latest.get('updated_at', ''),
            }, default=_decimal_default),
        }

    except Exception as e:
        print(f'Error in get_handler: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal Server Error'}),
        }
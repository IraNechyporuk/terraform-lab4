import json
import boto3
import os
from datetime import datetime, timezone
from collections import defaultdict
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('TABLE_NAME')
table = dynamodb.Table(TABLE_NAME)


def handler(event, context):
    """SQS ESM: event["Records"] містить список повідомлень з черги.

    ВИПРАВЛЕННЯ: замість put_item (який перезаписує дані) використовуємо
    update_item з ADD — атомарно додає до існуючих total_sum та sample_count.
    Завдяки цьому дані з різних батчів одного часового вікна не губляться.
    """
    records = event.get('Records', [])
    print(f'Processing {len(records)} SQS messages')

    # Групуємо за device_id та хвилинним вікном
    # key = (device_id, window_start) → список температур у цьому батчі
    windows = defaultdict(list)

    for record in records:
        body = json.loads(record['body'])
        device_id = body['device_id']
        temperature = float(body['temperature'])
        ts = datetime.fromisoformat(body['timestamp'].replace('Z', '+00:00'))

        # Ключ вікна = device_id + початок хвилини (без секунд)
        window_start = ts.strftime('%Y-%m-%dT%H:%M:00Z')
        windows[(device_id, window_start)].append(temperature)

    # Атомарно оновлюємо DynamoDB: ADD до існуючих значень
    for (device_id, window_start), temps in windows.items():
        batch_sum = Decimal(str(round(sum(temps), 6)))
        batch_count = len(temps)

        # ADD створює атрибут з нуля, якщо його ще не існує,
        # або додає до наявного значення — без race condition.
        table.update_item(
            Key={
                'device_id': device_id,
                'window_start': window_start,
            },
            UpdateExpression=(
                'ADD total_sum :s, sample_count :c '
                'SET updated_at = :now'
            ),
            ExpressionAttributeValues={
                ':s':   batch_sum,
                ':c':   batch_count,
                ':now': datetime.now(timezone.utc).isoformat(),
            },
        )
        print(
            f'Updated: device={device_id}, window={window_start}, '
            f'+sum={batch_sum}, +count={batch_count}'
        )

    return {
        'statusCode': 200,
        'body': f'Processed {len(records)} messages across {len(windows)} windows',
    }
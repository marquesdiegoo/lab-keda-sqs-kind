import boto3
import time
import os

queue_url = os.environ["QUEUE_URL"]
sqs = boto3.client("sqs", endpoint_url="http://host.docker.internal:4566", region_name="us-east-1")

print(f"Consumindo mensagens da fila: {queue_url}")

while True:
    messages = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1,
        WaitTimeSeconds=10
    )
    for msg in messages.get('Messages', []):
        print("Mensagem recebida:", msg['Body'])
        sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=msg['ReceiptHandle'])
    time.sleep(1)

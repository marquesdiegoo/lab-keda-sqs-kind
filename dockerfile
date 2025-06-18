FROM python:3.10
RUN pip install boto3
COPY consumer.py /app/consumer.py
WORKDIR /app
CMD ["python", "consumer.py"]

#!/bin/bash

# --- Configurações ---
SQS_ENDPOINT_URL="http://localhost:4566"
QUEUE_URL="http://localhost:4566/000000000000/minha-fila" # Sua URL da fila completa
NUM_REPETICOES=10 # Quantas vezes enviar a mensagem

# --- Executa o comando em um loop ---
echo "Iniciando o envio de $NUM_REPETICOES mensagens para a fila SQS..."

for i in $(seq 1 "$NUM_REPETICOES"); do
  echo "Enviando mensagem $i de $NUM_REPETICOES..."
  aws sqs send-message \
    --endpoint-url="$SQS_ENDPOINT_URL" \
    --queue-url "$QUEUE_URL" \
    --message-body "Mensagem teste $i" > /dev/null

  # Opcional: Adicione um pequeno atraso entre as mensagens para evitar sobrecarga
  sleep 2
done

echo "Envio de $NUM_REPETICOES mensagens concluído."
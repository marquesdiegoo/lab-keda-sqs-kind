### Laboratório local que demonstra como escalar automaticamente aplicações no Kubernetes usando o KEDA baseado em mensagens de uma fila SQS, tudo rodando de forma local com LocalStack e KIND. Ideal para testes, aprendizado e experimentação de cenários Cloud Native sem necessidade de infraestrutura em nuvem.


* **LocalStack** simulando os serviços da AWS (SQS).
* Uma **aplicação que consome uma fila SQS**.
* O **KEDA** observando a fila para escalar o pod da aplicação.
* Tudo rodando localmente usando **KIND (Kubernetes in Docker)**.

---

## 🧪 Visão Geral do Lab

### Componentes:

* `kind` → Cluster Kubernetes local.
* `localstack` → Emula SQS.
* `sqs-consumer-app` → App que consome mensagens da SQS.
* `KEDA` → Observa métricas da fila e escala o deployment.

---

## 🧱 Pré-requisitos

Instale no seu ambiente:

* **[Kind](https://kind.sigs.k8s.io/):** Kubernetes local em containers Docker.
* **[helm](https://helm.sh/docs/intro/install/):** Para instalação do KEDA como chart.
* **[LocalStack](https://localstack.cloud/):** Mock da AWS para testes locais.
* **[Docker](https://docs.docker.com/engine/install/):** Instalar Docker.
* **[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/):** Instalar kubectl.
* **[aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html):** Instalar aws-cli.

Docker precisa estar rodando.

---

## 1. 🧰 Subir Cluster e LocalStack com SQS

Crie o cluster:

```bash
kind create cluster --name crossplane-lab
```

Suba o LocalStack:

```bash
localstack start
```

Isso iniciará o LocalStack com o serviço SQS disponível na url http://localhost:4566 do seu host local.

#### Atenção:  

`Entre em outro terminal para continuar`

Criar o aquivo de credencia e config:

```bash
aws configure
AWS Access Key ID [None]: fake 
AWS Secret Access Key [None]: fake
Default region name [None]: us-east-1
Default output format [None]: json
```

---

## 2. 📦 Criar Fila SQS no LocalStack

```bash
aws sqs create-queue --queue-name minha-fila --endpoint-url=http://localhost:4566 > /dev/null
```

---

## 3. 📦 Aplicação que Consome Fila

Exemplo de app simples em Python (`consumer.py`):

```python
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

```

**Dockerfile:**

```Dockerfile
FROM python:3.10
RUN pip install boto3
COPY consumer.py /app/consumer.py
WORKDIR /app
CMD ["python", "consumer.py"]
```

Construa a imagem:

```bash
docker build -t sqs-consumer:v1 .
```


`TODOS OS ARQUIVO ESTÃO NO REPO`


---

## 4. ☸️ Subir o KIND

```bash
kind create cluster --name keda-lab
```

### Atenção 

Enviar a image criar para o cluster:

```bash
kind load docker-image sqs-consumer:v1 --name keda-lab
```

---

## 5. 🚀 Instalar o KEDA no cluster

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
```

---

## 6. 🧬 Configurar Deployment da App + KEDA ScaledObject

### Deployment da App:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sqs-consumer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sqs-consumer
  template:
    metadata:
      labels:
        app: sqs-consumer
    spec:
      containers:
        - name: consumer
          image: sqs-consumer:v1
          env:
            - name: QUEUE_URL
              value: http://host.docker.internal:4566/000000000000/minha-fila
            - name: AWS_ACCESS_KEY_ID
              value: test
            - name: AWS_SECRET_ACCESS_KEY
              value: test
            - name: AWS_DEFAULT_REGION
              value: us-east-1
```

### ServiceAccount para KEDA (caso necessário):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: keda-operator
  namespace: keda
```

### Secret com credenciais AWS (fictícia):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-secrets
type: Opaque
data:
  AWS_ACCESS_KEY_ID: dGVzdA==        # base64 de "test"
  AWS_SECRET_ACCESS_KEY: dGVzdA==    # base64 de "test"
```

### ScaledObject:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: sqs-scaledobject
spec:
  scaleTargetRef:
    name: sqs-consumer
  pollingInterval: 30 #Intervalo de tempo que o KEDA vai ficar batendo na SQS para verificar a fila
  cooldownPeriod: 5   #Tempo que o Pod consumidor vai ficar up sem trabalho
  minReplicaCount: 0  #Quantidade minima de PODs para atender as filas
  maxReplicaCount: 10 #Quantidade maxima de PODs para atender as filas
  triggers:
    - type: aws-sqs-queue
      metadata:
        queueURL: http://host.docker.internal:4566/000000000000/minha-fila
        queueLength: "1" #Quantidade de mensagens que cada POD vai consumir por vez 
        awsRegion: "us-east-1"
        awsEndpoint: http://host.docker.internal:4566
      authenticationRef:
        name: keda-aws-auth
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: keda-aws-auth
spec:
  secretTargetRef:
    - parameter: awsAccessKeyID
      name: aws-secrets
      key: AWS_ACCESS_KEY_ID
    - parameter: awsSecretAccessKey
      name: aws-secrets
      key: AWS_SECRET_ACCESS_KEY

```

`TODOS OS ARQUIVO ESTÃO NO REPO`

---

## 7. 🧪 Testar Escalonamento

1. Aplique todos os manifests:

```bash
kubectl apply -f deployment.yaml
kubectl apply -f secrets.yaml
kubectl apply -f scaledobject.yaml
```

2. Enfileire mensagens:

Enfileire um mensagen:

```bash
aws sqs send-message --queue-url http://localhost:4566/000000000000/minha-fila --message-body "Hello KEDA" --endpoint-url=http://localhost:4566 > /dev/null
```

Script para N mensagens: 

```bash
chamod +x enviar-mensagens.sh
./enviar-mensagens.sh
```

3. Veja o `pod` sendo escalado com:

```bash
kubectl get pods -w
```

---

## ✅ Resultado Esperado

* Quando não houver mensagens → 0 réplicas.
* Quando houver mensagens → KEDA escala o pod automaticamente.
* O consumer lê e apaga a mensagem.

---

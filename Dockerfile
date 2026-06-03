FROM python:3.11-slim

RUN apt-get update && apt-get install -y libcairo2 pkg-config && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY server/ ./server/

CMD ["python", "server/server.py"]
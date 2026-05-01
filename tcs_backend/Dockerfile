FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev libmagic1 libmagic-dev \
    libjpeg-dev libpng-dev ffmpeg curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p staticfiles media logs

EXPOSE 8000

CMD ["daphne", "-b", "0.0.0.0", "-p", "8000", "--proxy-headers", "TCS.asgi:application"]

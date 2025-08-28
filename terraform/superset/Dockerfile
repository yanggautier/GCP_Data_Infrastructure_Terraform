FROM apache/superset:latest

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     gcc \
     libpq-dev \
     python3-dev \
  && pip install --no-cache-dir psycopg2==2.9.9 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

USER superset


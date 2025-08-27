FROM apache/superset:latest

USER root

# Dépendances système pour psycopg2
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     gcc \
     libpq-dev \
     python3-dev \
  && rm -rf /var/lib/apt/lists/*

# Installer psycopg2
RUN pip install --no-cache-dir psycopg2-binary==2.9.9

USER superset

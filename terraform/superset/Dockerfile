FROM apache/superset:latest

# Passer en utilisateur root
USER root

# Installer toutes les dépendances dans l'environnement virtuel
RUN pip install \
    psycopg2-binary==2.9.10 \
    pandas \
    numpy \
    google-cloud-bigquery

# Revenir à l'utilisateur superset
USER superset
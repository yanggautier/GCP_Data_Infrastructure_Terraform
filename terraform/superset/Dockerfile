FROM apache/superset:latest

# Passer en utilisateur root
USER root

# Installer toutes les dépendances dans l'environnement virtuel
RUN pip install \
    psycopg2-binary==2.9.10 \
    pandas \
    numpy \
    google-cloud-bigquery

# Vérifier que l'installation a réussi
RUN python "import psycopg2; print('psycopg2 installed successfully')"

# Revenir à l'utilisateur superset
USER superset
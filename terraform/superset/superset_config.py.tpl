import os
from cachelib.redis import RedisCache


DATABASE_USER = ${database_user}
DATABASE_PASSWORD = ${database_password}
DATABASE_HOST = ${database_host}
DATABASE_PORT = "5432"
DATABASE_NAME = ${database_name}

# Database configuration
SQLALCHEMY_DATABASE_URI = f"postgresql://{DATABASE_USER}:{DATABASE_PASSWORD}@{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_NAME}"

# Redis configuration for caching and Celery
REDIS_HOST = "${redis_host}"
REDIS_PORT = 6379

# Cache configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': REDIS_HOST,
    'CACHE_REDIS_PORT': REDIS_PORT,
}

# Celery configuration (for async queries)
class CeleryConfig(object):
    broker_url = f'redis://{REDIS_HOST}:{REDIS_PORT}/0'
    imports = ('superset.sql_lab',)
    result_backend = f'redis://{REDIS_HOST}:{REDIS_PORT}/0'
    worker_prefetch_multiplier = 1
    task_acks_late = True

CELERY_CONFIG = CeleryConfig

# Security configuration
SECRET_KEY = "${secret_key}"

# Feature flags
FEATURE_FLAGS = {
    "ALERT_REPORTS": True,
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "DASHBOARD_FILTERS_EXPERIMENTAL": True,
    "DRILL_TO_DETAIL": True,
    "DRILL_BY": True,
    "ENABLE_TEMPLATE_PROCESSING": True,
}

# Authentication configuration (adjust as needed)
AUTH_TYPE = 1  # Database authentication
AUTH_ROLE_ADMIN = 'Admin'
AUTH_ROLE_PUBLIC = 'Public'

# Optional: Configure CORS if needed
ENABLE_CORS = True
CORS_OPTIONS = {
    'supports_credentials': True,
    'allow_headers': ['*'],
    'expose_headers': ['*'],
    'resources': ['*'],
    'origins': ['*']
}

# Logging configuration
import logging
logging.basicConfig(level=logging.INFO)

# Row limit for SQL Lab
DEFAULT_SQLLAB_LIMIT = 5000
SQL_MAX_ROW = 100000

# CSV export encoding
CSV_EXPORT = {
    'encoding': 'utf-8',
}

# Enable public role
PUBLIC_ROLE_LIKE_GAMMA = True
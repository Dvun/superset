# superset_config.py

import os
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from redis import Redis

# =====================
# Database Configuration
# =====================

POSTGRES_DB_NAME = os.getenv('POSTGRES_DB_NAME', 'vanttidevtest')

if not POSTGRES_DB_NAME:
    raise ValueError("POSTGRES_DB_NAME is not set!")

SQLALCHEMY_DATABASE_URI = f'postgresql+psycopg2://postgres:postgres@superset_db:5432/{POSTGRES_DB_NAME}'

# =====================
# Flask-Limiter Configuration
# =====================

# Initialize Redis client
redis_host = os.getenv('REDIS_HOST', 'superset_cache')
redis_port = int(os.getenv('REDIS_PORT', 6379))
redis_client = Redis(host=redis_host, port=redis_port, decode_responses=True)

# Configure Limiter with Redis storage
limiter = Limiter(
    key_func=get_remote_address,
    storage_uri=f"redis://{redis_host}:{redis_port}",
    default_limits=["200 per day", "50 per hour"]
)

# Attach Limiter to Superset's Flask app
def init_app(app):
    limiter.init_app(app)
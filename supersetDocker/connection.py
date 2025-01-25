import os
import requests
import logging

# Set the logging level to CRITICAL to suppress lower-level messages
logging.basicConfig(level=logging.CRITICAL)

# Superset configuration
SUPERSET_USERNAME = os.getenv('SUPERSET_USERNAME', 'admin')
SUPERSET_PASSWORD = os.getenv('SUPERSET_PASSWORD', 'admin')
SUPERSET_URL = os.getenv('SUPERSET_URL', 'http://localhost:8088')

# Database configuration
POSTGRES_DB_NAME = os.getenv('POSTGRES_DB_NAME')
POSTGRES_USER = os.getenv('POSTGRES_USER', 'postgres')
POSTGRES_PASSWORD = os.getenv('POSTGRES_PASSWORD', 'postgres')
POSTGRES_HOST = os.getenv('POSTGRES_HOST', 'superset_db')
POSTGRES_PORT = os.getenv('POSTGRES_PORT', '5432')

# SQLAlchemy URI
sqlalchemy_uri = f"postgresql+psycopg2://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB_NAME}"

# Superset API endpoints
login_endpoint = f"{SUPERSET_URL}/api/v1/security/login"
csrf_token_endpoint = f"{SUPERSET_URL}/api/v1/security/csrf_token"
database_endpoint = f"{SUPERSET_URL}/api/v1/database/"
database_search_endpoint = f"{SUPERSET_URL}/api/v1/database/?q={{\"filters\":[{{\"col\":\"database_name\",\"opr\":\"eq\",\"value\":\"{POSTGRES_DB_NAME}\"}}]}}"

# Start a session
session = requests.Session()

# Login to Superset
login_response = session.post(
    login_endpoint,
    json={"username": SUPERSET_USERNAME, "password": SUPERSET_PASSWORD, "provider": "db"}
)

if login_response.status_code != 200:
    raise Exception(f"Failed to log in to Superset: {login_response.text}")

print("Successfully logged in.")

# Extract the access token
access_token = login_response.json().get("access_token")
if not access_token:
    raise Exception("Access token is missing in login response.")

# Update session headers with the access token
session.headers.update({"Authorization": f"Bearer {access_token}"})

# Fetch the CSRF token
csrf_response = session.get(csrf_token_endpoint)
if csrf_response.status_code != 200:
    raise Exception(f"Failed to fetch CSRF token: {csrf_response.text}")

csrf_token = csrf_response.json().get("result")
if not csrf_token:
    raise Exception("Failed to retrieve CSRF token.")

# Update session headers with the CSRF token
session.headers.update({"X-CSRFToken": csrf_token, "Content-Type": "application/json"})

# Check if the database already exists
search_response = session.get(database_search_endpoint)
if search_response.status_code == 200:
    if search_response.json().get("count", 0) > 0:
        print("Database connection already exists. No action needed.")
        exit(0)

# Add the database connection
database_payload = {
    "database_name": POSTGRES_DB_NAME,
    "sqlalchemy_uri": sqlalchemy_uri,
    "expose_in_sqllab": True,
    "allow_run_async": True,
}

response = session.post(database_endpoint, json=database_payload)

if response.status_code == 201:
    print("Database connection added successfully.")
else:
    print(f"Failed to add database connection: {response.json()}")

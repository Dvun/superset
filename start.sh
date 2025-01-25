#!/bin/bash

# start.sh

set -e  # Exit immediately if a command exits with a non-zero status

# Function to print messages with timestamps
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')]: $1"
}

# Check if a database name is provided
if [ -z "$1" ]; then
  echo "Usage: ./start.sh <database_name>"
  exit 1
fi

POSTGRES_DB_NAME=$1

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the path to the project directory
# Replace 'supersetDocker' with your actual folder name if different
PROJECT_DIR="$SCRIPT_DIR/supersetDocker"

# Check if the project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
  log "Error: Directory '$PROJECT_DIR' does not exist."
  exit 1
fi

# Export the database name as an environment variable
export POSTGRES_DB_NAME

# Create or update the .env file with the provided database name
echo "POSTGRES_DB_NAME=$POSTGRES_DB_NAME" > "$PROJECT_DIR/.env"

# Optionally, set SUPERSET_SECRET_KEY if not already set
if grep -q "^SUPERSET_SECRET_KEY=" "$PROJECT_DIR/.env"; then
  log "SUPERSET_SECRET_KEY already set in .env."
else
  # For simplicity, setting a hardcoded secret key (Replace with secure key in production)
  SUPERSET_SECRET_KEY="SUPER_SECRET_KEY"
  echo "SUPERSET_SECRET_KEY=$SUPERSET_SECRET_KEY" >> "$PROJECT_DIR/.env"
  log "SUPERSET_SECRET_KEY generated and added to .env."
fi

# Navigate to the project directory
cd "$PROJECT_DIR"

# Build the Superset Docker image to apply any changes
log "Building Superset Docker image..."
docker-compose build superset >/dev/null 2>&1
log "Superset Docker image built."

# Start Docker services in detached mode and suppress output
log "Starting Docker services..."
docker-compose up -d >/dev/null 2>&1
log "Docker services started."

# Wait for PostgreSQL to be ready
log "Waiting for PostgreSQL to be ready..."
until docker exec superset_db pg_isready -U postgres >/dev/null 2>&1; do
  log "PostgreSQL is not ready yet. Retrying in 2 seconds..."
  sleep 2
done
log "PostgreSQL is ready."

# Create the database if it doesn't exist
if docker exec superset_db psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$POSTGRES_DB_NAME'" | grep -q 1; then
  log "Database '$POSTGRES_DB_NAME' already exists."
else
  log "Creating database '$POSTGRES_DB_NAME'."
  docker exec superset_db psql -U postgres -c "CREATE DATABASE $POSTGRES_DB_NAME" >/dev/null 2>&1
  log "Database '$POSTGRES_DB_NAME' created."
fi

# Initialize Superset
log "Initializing Superset database..."
docker exec superset_app superset db upgrade >/dev/null 2>&1
log "Superset database initialized."

# Check if the admin user already exists
if docker exec superset_app superset fab list-users | grep -q "admin"; then
  log "Admin user already exists. Skipping admin creation."
else
  log "Creating admin user."
  docker exec superset_app superset fab create-admin \
    --username admin \
    --firstname Superset \
    --lastname Admin \
    --email admin@superset.com \
    --password admin >/dev/null 2>&1
  log "Admin user created."
fi

# Finalize Superset initialization
log "Finalizing Superset initialization..."
docker exec superset_app superset init >/dev/null 2>&1
log "Superset initialization finalized."

# Ensure the connection.py file is copied into the container
if [ -f "$PROJECT_DIR/connection.py" ]; then
  log "Copying connection.py to the container..."
  docker cp "$PROJECT_DIR/connection.py" superset_app:/app/connection.py >/dev/null 2>&1 && \
    log "connection.py script copied successfully." || \
    { log "Error: Failed to copy connection.py into the container."; exit 1; }
else
  log "Error: connection.py does not exist in the project directory."
  exit 1
fi

# Run the Python script to handle database connections
log "Running connection.py inside the container..."
if docker exec superset_app python3 /app/connection.py >/dev/null 2>&1; then
  log "Database connection added or already exists."
else
  log "Error: Failed to run connection.py inside the container."
  exit 1
fi

# Call the initializeSchemaAndDatasets.sh script
log "Initializing 'datasets' schema and managing datasets..."
./initializeSchemaAndDatasets.sh "$POSTGRES_DB_NAME"
log "'datasets' schema and datasets initialized successfully."

log "Superset is ready and running!"

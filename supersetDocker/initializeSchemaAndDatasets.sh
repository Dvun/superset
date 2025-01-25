#!/bin/bash

# This script initializes the 'datasets' schema and manages table creation and updates from SQL files.

set -e  # Exit immediately if a command exits with a non-zero status

# Function to print messages with timestamps
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')]: $1"
}

# Configuration
POSTGRES_USER="postgres"                # PostgreSQL username
POSTGRES_PASSWORD="postgres"            # PostgreSQL password
POSTGRES_HOST="superset_db"             # PostgreSQL container name
POSTGRES_PORT=5432                      # PostgreSQL port
DATABASE_NAME="$1"                      # Database name passed as argument
DATASETS_DIR="../datasets"               # Directory containing .sql files

# Usage check
if [ -z "$DATABASE_NAME" ]; then
  echo "Usage: ./initializeSchemaAndDatasets.sh <database_name>"
  exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  log "Error: Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check if PostgreSQL container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_HOST}$"; then
  log "Error: PostgreSQL container '${POSTGRES_HOST}' is not running."
  exit 1
fi

# Check if Superset container is running
if ! docker ps --format '{{.Names}}' | grep -q "^superset_app$"; then
  log "Error: Superset container 'superset_app' is not running."
  exit 1
fi

# Create the 'datasets' schema if it doesn't exist
log "Creating 'datasets' schema if it doesn't exist..."
docker exec -u postgres "${POSTGRES_HOST}" psql -U "${POSTGRES_USER}" -d "${DATABASE_NAME}" -c "CREATE SCHEMA IF NOT EXISTS datasets;" >/dev/null 2>&1
log "'datasets' schema is ready."

# Iterate over all .sql files in the datasets directory
log "Processing SQL files in '${DATASETS_DIR}' directory..."

for sql_file in "${DATASETS_DIR}"/*.sql; do
  # Check if there are any .sql files
  if [ ! -e "$sql_file" ]; then
    log "No .sql files found in '${DATASETS_DIR}'. Skipping table insertion."
    break
  fi

  # Extract the table name from the file name
  # Assumes file name format: table_name.sql
  table_name=$(basename "$sql_file" .sql)

  log "Processing table '${table_name}'..."

  # Check if the table exists in the 'datasets' schema
  table_exists=$(docker exec -u postgres "${POSTGRES_HOST}" psql -U "${POSTGRES_USER}" -d "${DATABASE_NAME}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'datasets' AND table_name = '${table_name}');")

  if [ "$table_exists" = "t" ]; then
    log "Table 'datasets.${table_name}' already exists. Attempting to apply updates..."
    # Execute the .sql file to apply any updates (assuming the script handles idempotency)
    docker exec -u postgres "${POSTGRES_HOST}" psql -U "${POSTGRES_USER}" -d "${DATABASE_NAME}" -f "/tmp/${table_name}.sql" >/dev/null 2>&1 || {
      log "Error: Failed to apply updates to table 'datasets.${table_name}'."
      exit 1
    }
    log "Updates applied to table 'datasets.${table_name}'."
  else
    log "Table 'datasets.${table_name}' does not exist. Creating table..."
    # Copy the .sql file into the PostgreSQL container
    docker cp "$sql_file" "${POSTGRES_HOST}":/tmp/"${table_name}".sql >/dev/null 2>&1

    # Execute the .sql file to create the table
    docker exec -u postgres "${POSTGRES_HOST}" psql -U "${POSTGRES_USER}" -d "${DATABASE_NAME}" -f "/tmp/${table_name}.sql" >/dev/null 2>&1 || {
      log "Error: Failed to create table 'datasets.${table_name}'."
      exit 1
    }
    log "Table 'datasets.${table_name}' created successfully."
  fi

done

log "All SQL files have been processed."

# Clean up: Remove copied .sql files from PostgreSQL container
log "Cleaning up temporary SQL files in PostgreSQL container..."
docker exec -u postgres "${POSTGRES_HOST}" bash -c "rm -f /tmp/*.sql" >/dev/null 2>&1
log "Cleanup completed."

log "Schema initialization and dataset management completed successfully!"

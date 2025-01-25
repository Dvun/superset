# Dockerfile

FROM apache/superset:latest

# Switch to root to install system packages and Python dependencies
USER root

# Install system dependencies and Python packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    pip install --no-cache-dir psycopg2-binary pillow && \
    rm -rf /var/lib/apt/lists/*

# Switch back to the superset user
USER superset

#!/bin/bash
# Startup script that runs migrations then starts the application

set -e

echo "Starting application..."

# Run migrations
echo "Running database migrations..."
bash /app/run_migrations.sh

# Start the application
echo "Starting FastAPI server..."
exec uvicorn main:app --host 0.0.0.0 --port 8000 --reload

#!/bin/bash
# Migration runner script
# This script runs all SQL migrations in order

set -e

echo "=========================================="
echo "Database Migration Runner"
echo "=========================================="

# Database connection parameters from environment variables
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-absensi_db}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD}"

# Wait for database to be ready
echo "Waiting for database to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" --silent 2>/dev/null; then
        echo "✓ Database is ready!"
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting for database... (attempt $attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "✗ Database connection failed after $max_attempts attempts"
    exit 1
fi

# Create migration tracking table if it doesn't exist
echo "Creating migration tracking table..."
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS schema_migrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    version VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    executed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_version (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF

echo "✓ Migration tracking table ready"

# Run migrations in order
MIGRATION_DIR="/app/migrations"
cd "$MIGRATION_DIR"

for migration_file in $(ls -1 *.sql 2>/dev/null | sort); do
    version=$(basename "$migration_file" .sql | cut -d'_' -f1)
    name=$(basename "$migration_file" .sql)
    
    # Check if migration has already been applied
    already_applied=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM schema_migrations WHERE version='$version'")
    
    if [ "$already_applied" -gt 0 ]; then
        echo "⊙ Migration $migration_file already applied, skipping..."
    else
        echo "→ Running migration: $migration_file"
        
        # Run the migration
        if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$migration_file"; then
            # Record successful migration
            mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "INSERT INTO schema_migrations (version, name) VALUES ('$version', '$name')"
            echo "✓ Migration $migration_file completed successfully"
        else
            echo "✗ Migration $migration_file failed!"
            exit 1
        fi
    fi
done

echo "=========================================="
echo "All migrations completed successfully!"
echo "=========================================="

# Show applied migrations
echo "Applied migrations:"
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT version, name, executed_at FROM schema_migrations ORDER BY version"

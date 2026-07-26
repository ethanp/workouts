#!/bin/bash
# Apply a workouts DB migration via the shared infra migrate script.
#
# Usage (from Flutter/workouts):
#   ./scripts/migrate.sh migrations/014_description.sql
#   ./scripts/migrate.sh --full migrations/014_description.sql

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_ROOT="$(cd "$APP_ROOT/../../infra" && pwd)"

MODE_ARGS=()
while [[ $# -gt 0 && "$1" == -* ]]; do
  MODE_ARGS+=("$1")
  shift
done

if [ -z "$1" ]; then
  echo "Usage: ./scripts/migrate.sh [-q|--quick|-f|--full] <migration-file>"
  echo "Example: ./scripts/migrate.sh migrations/014_description.sql"
  exit 1
fi

MIGRATION_FILE="$1"

if [[ "$MIGRATION_FILE" != /* ]]; then
  if [ -f "$APP_ROOT/db/$MIGRATION_FILE" ]; then
    MIGRATION_FILE="$APP_ROOT/db/$MIGRATION_FILE"
  elif [ -f "$APP_ROOT/$MIGRATION_FILE" ]; then
    MIGRATION_FILE="$APP_ROOT/$MIGRATION_FILE"
  fi
fi

if [ ! -f "$MIGRATION_FILE" ]; then
  echo "Error: Migration file not found: $1"
  exit 1
fi

exec "$INFRA_ROOT/migrate.sh" "${MODE_ARGS[@]}" --app workouts "$MIGRATION_FILE"

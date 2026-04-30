#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env if present; env vars already exported take precedence
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

# Validate required variables
: "${POSTGRES_HOST:?Set POSTGRES_HOST in .env or environment}"
: "${POSTGRES_PORT:?Set POSTGRES_PORT in .env or environment}"
: "${POSTGRES_DB:?Set POSTGRES_DB in .env or environment}"
: "${POSTGRES_USER:?Set POSTGRES_USER in .env or environment}"
: "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env or environment}"

# ---------------------------------------------------------------------------
# Step 1: Resolve PostgreSQL container and Docker network
#
# Case A: POSTGRES_HOST is a container name          -> use it directly
# Case B: POSTGRES_HOST is localhost / 127.0.0.1
#         and a postgis/postgis container is running  -> borrow its network
# Case C: no Docker container found                  -> --network host (EC2 native)
# ---------------------------------------------------------------------------
PG_CONTAINER=""
EFFECTIVE_HOST="$POSTGRES_HOST"

if docker inspect "$POSTGRES_HOST" > /dev/null 2>&1; then
  PG_CONTAINER="$POSTGRES_HOST"
  NETWORK=$(docker inspect "$POSTGRES_HOST" \
    --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}')
else
  FOUND=$(docker ps \
    --filter "publish=$POSTGRES_PORT" \
    --format "{{.Names}}" 2>/dev/null | head -1 || true)

  if [ -n "$FOUND" ]; then
    PG_CONTAINER="$FOUND"
    EFFECTIVE_HOST="$FOUND"
    NETWORK=$(docker inspect "$FOUND" \
      --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}')
    echo "Resolved '$POSTGRES_HOST' -> container '$PG_CONTAINER' (network: $NETWORK)"
  else
    NETWORK=""
  fi
fi

if [ -n "$NETWORK" ]; then
  NETWORK_ARGS=(--network "$NETWORK")
else
  echo "No Docker container found for '$POSTGRES_HOST'; using host network."
  NETWORK_ARGS=(--network host)
fi

# ---------------------------------------------------------------------------
# Step 2: Wait for PostgreSQL to be ready
# ---------------------------------------------------------------------------
echo "Waiting for PostgreSQL..."
if [ -n "$PG_CONTAINER" ]; then
  until docker exec "$PG_CONTAINER" \
      pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q 2>/dev/null; do
    sleep 1
  done
else
  until PGPASSWORD="$POSTGRES_PASSWORD" psql \
      -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
      -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
      -c "" > /dev/null 2>&1; do
    sleep 1
  done
fi
echo "PostgreSQL ready."

# ---------------------------------------------------------------------------
# Step 3: Apply schema (all statements are idempotent)
# ---------------------------------------------------------------------------
echo "Applying schema..."
if [ -n "$PG_CONTAINER" ]; then
  docker exec -i "$PG_CONTAINER" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    < "$SCRIPT_DIR/sql/01_extensions.sql"
  docker exec -i "$PG_CONTAINER" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    < "$SCRIPT_DIR/sql/02_schema.sql"
else
  PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    < "$SCRIPT_DIR/sql/01_extensions.sql"
  PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    < "$SCRIPT_DIR/sql/02_schema.sql"
fi
echo "Schema applied."

# ---------------------------------------------------------------------------
# Step 4: Load data
# ---------------------------------------------------------------------------
echo "Loading data..."
MSYS_NO_PATHCONV=1 docker run --rm \
  "${NETWORK_ARGS[@]}" \
  -v "$SCRIPT_DIR:/app" \
  -w /app \
  -e POSTGRES_HOST="$EFFECTIVE_HOST" \
  -e POSTGRES_PORT \
  -e POSTGRES_DB \
  -e POSTGRES_USER \
  -e POSTGRES_PASSWORD \
  -e GDRIVE_WAYS_URL="${GDRIVE_WAYS_URL:-}" \
  -e GDRIVE_CROSSINGS_URL="${GDRIVE_CROSSINGS_URL:-}" \
  python:3.11-slim \
  bash -c "pip install -r requirements.txt -q && python -m loader.load"

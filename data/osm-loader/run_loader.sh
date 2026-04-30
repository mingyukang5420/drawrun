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

# Resolve Docker network.
# Case 1: POSTGRES_HOST is a container name  -> use that container's network directly.
# Case 2: POSTGRES_HOST is localhost/127.0.0.1 on Docker Desktop (Windows/Mac)
#         -> find localPostgis container and borrow its network, override host to container name.
# Case 3: POSTGRES_HOST is localhost on Linux EC2 with native PostgreSQL
#         -> --network host.
EFFECTIVE_HOST="$POSTGRES_HOST"
NETWORK=$(docker inspect "$POSTGRES_HOST" \
  --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null || true)

if [ -z "$NETWORK" ] && [ "$POSTGRES_HOST" = "localhost" -o "$POSTGRES_HOST" = "127.0.0.1" ]; then
  # Try to find a running PostGIS/Postgres container as the actual target
  FALLBACK_CONTAINER=$(docker ps --filter "publish=$POSTGRES_PORT" \
    --filter "ancestor=postgis/postgis" \
    --format "{{.Names}}" 2>/dev/null | head -1 || true)

  if [ -n "$FALLBACK_CONTAINER" ]; then
    NETWORK=$(docker inspect "$FALLBACK_CONTAINER" \
      --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null || true)
    EFFECTIVE_HOST="$FALLBACK_CONTAINER"
    echo "Resolved localhost -> container '$FALLBACK_CONTAINER' on network '$NETWORK'"
  fi
fi

if [ -n "$NETWORK" ]; then
  NETWORK_ARGS=(--network "$NETWORK")
else
  # EC2 with native PostgreSQL: --network host lets the container reach localhost
  echo "No Docker container found for '$POSTGRES_HOST'; using host network."
  NETWORK_ARGS=(--network host)
fi

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

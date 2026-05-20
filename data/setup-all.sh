#!/bin/bash
# 시연용 DB 원터치 셋업.
#
# 전제: PostgreSQL + Redis 컨테이너가 이미 떠 있어야 한다 (be/docker-compose up -d).
#
# 동작:
#   1) data/osm-loader/run_loader.sh       → 스키마 + osm_ways(+split) + osm_crossings + districts
#   2) data/mock-loader (python container) → members, tracks, challenges, course_drafts,
#                                            records, courses, course_bookmark, member_record_stats
#
# 환경변수는 data/osm-loader/.env 를 그대로 재사용.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# [1/2] OSM + districts 적재 (기존 스크립트에 위임)
# ---------------------------------------------------------------------------
echo "==================================================================="
echo " [1/2] OSM + districts 적재"
echo "==================================================================="
bash "$SCRIPT_DIR/osm-loader/run_loader.sh"

# ---------------------------------------------------------------------------
# [2/2] Mockup 적재
# ---------------------------------------------------------------------------
echo ""
echo "==================================================================="
echo " [2/2] Mockup 데이터 적재"
echo "==================================================================="

ENV_FILE="$SCRIPT_DIR/osm-loader/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

: "${POSTGRES_HOST:?Set POSTGRES_HOST in $ENV_FILE}"
: "${POSTGRES_PORT:?Set POSTGRES_PORT in $ENV_FILE}"
: "${POSTGRES_DB:?Set POSTGRES_DB}"
: "${POSTGRES_USER:?Set POSTGRES_USER}"
: "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD}"

# run_loader.sh 와 동일한 Docker 네트워크 감지 로직.
# 별도 헬퍼로 빼지 않고 의도적으로 중복 유지 — 두 스크립트가 독립 실행 가능해야 한다.
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

MSYS_NO_PATHCONV=1 docker run --rm \
  "${NETWORK_ARGS[@]}" \
  -v "$SCRIPT_DIR/mock-loader:/app" \
  -w /app \
  -e POSTGRES_HOST="$EFFECTIVE_HOST" \
  -e POSTGRES_PORT \
  -e POSTGRES_DB \
  -e POSTGRES_USER \
  -e POSTGRES_PASSWORD \
  python:3.11-slim \
  bash -c "pip install -r requirements.txt -q && python -m loader.load"

echo ""
echo "==================================================================="
echo " 완료"
echo "==================================================================="
echo " 시연 로그인 계정: demo01 ~ demo20 / password1!"

#!/bin/bash
# dev(EC2) DB → snapshot.sql 최초 생성.
#
# 9개 도메인 테이블만 --data-only 로 떠서 snapshot.sql 로 저장한다.
# OSM/districts 는 OSM-loader 가 따로 적재하므로 제외.
# 이미 snapshot.sql 이 있으면 update.sh 로 안내 후 종료.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
OUT_FILE="$SCRIPT_DIR/snapshot.sql"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE 가 없습니다. .env.example 을 복사해 채워주세요." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

: "${DEV_DB_HOST:?DEV_DB_HOST not set}"
: "${DEV_DB_PORT:?DEV_DB_PORT not set}"
: "${DEV_DB_NAME:?DEV_DB_NAME not set}"
: "${DEV_DB_USERNAME:?DEV_DB_USERNAME not set}"
: "${DEV_DB_PASSWORD:?DEV_DB_PASSWORD not set}"
: "${LOCAL_PG_CONTAINER:?LOCAL_PG_CONTAINER not set}"

if [ -f "$OUT_FILE" ]; then
  echo "ERROR: snapshot.sql 이 이미 존재합니다." >&2
  echo "       기존 파일을 갱신하려면 update.sh 를 사용하세요." >&2
  exit 1
fi

# dev DB 9개 도메인 테이블만 dump (FK 의존성 위상 정렬은 pg_dump 가 알아서).
# --column-inserts 로 컬럼명 포함 INSERT 문 생성 — diff 가독성 + 컬럼 변경 내성.
# PostGIS geometry 는 pg_dump 가 EWKB hex 로 직렬화 → 복원 시 그대로 살아난다.
TABLES=(
  public.members
  public.tracks
  public.records
  public.courses
  public.course_drafts
  public.course_district
  public.course_bookmark
  public.challenges
  public.member_record_stats
)

PG_DUMP_ARGS=(
  -h "$DEV_DB_HOST" -p "$DEV_DB_PORT"
  -U "$DEV_DB_USERNAME" -d "$DEV_DB_NAME"
  --data-only --no-owner --no-acl --no-privileges
  --column-inserts
)
for t in "${TABLES[@]}"; do
  PG_DUMP_ARGS+=(-t "$t")
done

echo "==================================================================="
echo " snapshot.sql 생성 시작"
echo "   source: $DEV_DB_USERNAME@$DEV_DB_HOST:$DEV_DB_PORT/$DEV_DB_NAME"
echo "   tables: ${#TABLES[@]} 개"
echo "==================================================================="

docker exec -e PGPASSWORD="$DEV_DB_PASSWORD" "$LOCAL_PG_CONTAINER" \
  pg_dump "${PG_DUMP_ARGS[@]}" > "$OUT_FILE"

INSERT_COUNT=$(grep -c "^INSERT INTO " "$OUT_FILE" || true)
FILE_SIZE=$(wc -c < "$OUT_FILE" | tr -d ' ')

echo ""
echo "==================================================================="
echo " 완료: $OUT_FILE"
echo "   INSERT 문: $INSERT_COUNT 개"
echo "   파일 크기: $FILE_SIZE bytes"
echo "==================================================================="

#!/bin/bash
# snapshot.sql → dev(EC2) DB 적재 (초기 상태 복원).
#
# 흐름:
#   1) 도메인 9개 테이블 + orders TRUNCATE ... RESTART IDENTITY CASCADE
#   2) snapshot.sql 의 INSERT 들을 그대로 실행
#   3) 전체를 BEGIN/COMMIT 트랜잭션으로 감싸 실패 시 자동 롤백.
#
# Redis, 업로드 파일, OSM/districts 테이블은 건드리지 않는다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
SNAPSHOT_FILE="$SCRIPT_DIR/snapshot.sql"

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

if [ ! -f "$SNAPSHOT_FILE" ]; then
  echo "ERROR: $SNAPSHOT_FILE 가 없습니다. dump.sh 를 먼저 실행하세요." >&2
  exit 1
fi

# TRUNCATE 대상: snapshot 에 들어있는 9개 + orders (entity 코드엔 없지만 dev DB 에 남아있는 잔재).
TRUNCATE_TABLES="course_bookmark, course_district, courses, records, tracks, challenges, member_record_stats, course_drafts, members, orders"

DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

# CLI 플래그 (--dry-run, --yes) 도 지원.
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

echo "==================================================================="
echo " dev DB 초기 상태 복원"
echo "   target:   $DEV_DB_USERNAME@$DEV_DB_HOST:$DEV_DB_PORT/$DEV_DB_NAME"
echo "   snapshot: $SNAPSHOT_FILE"
echo "   TRUNCATE: $TRUNCATE_TABLES"
echo "   keep:     osm_ways, osm_ways_split, osm_crossings, districts"
echo "             + Redis, 업로드 파일 (건드리지 않음)"
echo "==================================================================="

PSQL_CMD=(
  docker exec -i -e PGPASSWORD="$DEV_DB_PASSWORD" "$LOCAL_PG_CONTAINER"
  psql -h "$DEV_DB_HOST" -p "$DEV_DB_PORT" -U "$DEV_DB_USERNAME" -d "$DEV_DB_NAME"
  -v ON_ERROR_STOP=1
)

# 현재 dev DB row count (실행 전 상태) 보여주기.
echo ""
echo " [실행 전] dev DB row count:"
"${PSQL_CMD[@]}" -tAc "
SELECT format('   %-22s %5s', t, count) FROM (
  SELECT 'members'             AS t, count(*)::text AS count FROM members
  UNION ALL SELECT 'tracks',              count(*)::text FROM tracks
  UNION ALL SELECT 'records',             count(*)::text FROM records
  UNION ALL SELECT 'courses',             count(*)::text FROM courses
  UNION ALL SELECT 'course_drafts',       count(*)::text FROM course_drafts
  UNION ALL SELECT 'course_district',     count(*)::text FROM course_district
  UNION ALL SELECT 'course_bookmark',     count(*)::text FROM course_bookmark
  UNION ALL SELECT 'challenges',          count(*)::text FROM challenges
  UNION ALL SELECT 'member_record_stats', count(*)::text FROM member_record_stats
  UNION ALL SELECT 'orders',              count(*)::text FROM orders
) s;
"

if [ "$DRY_RUN" = "1" ]; then
  echo ""
  echo " --dry-run: 실제 TRUNCATE/INSERT 는 수행하지 않습니다."
  echo "            (snapshot.sql 의 INSERT 문 수: $(grep -c '^INSERT INTO ' "$SNAPSHOT_FILE" || true))"
  exit 0
fi

# 위험한 작업이므로 명시적 확인.
if [ "$ASSUME_YES" != "1" ]; then
  echo ""
  echo " ⚠️  위 테이블들이 모두 TRUNCATE 되고 snapshot 상태로 덮어쓰입니다."
  read -r -p " 계속하시겠습니까? (yes 만 입력하면 진행): " ans
  if [ "$ans" != "yes" ]; then
    echo " 취소되었습니다."
    exit 0
  fi
fi

echo ""
echo " 적재 중..."

# TRUNCATE + snapshot 적재를 한 트랜잭션으로.
# psql 의 \i 는 stdin 으로 들어온 SQL 안에서 외부 파일을 읽으므로,
# snapshot.sql 을 그대로 stdin 으로 흘려넣고 앞뒤에 BEGIN/TRUNCATE/COMMIT 만 붙인다.
{
  echo "BEGIN;"
  echo "SET session_replication_role = replica;"  # FK 제약 일시 무시 (이미 TRUNCATE CASCADE 되어 안전)
  echo "TRUNCATE TABLE $TRUNCATE_TABLES RESTART IDENTITY CASCADE;"
  cat "$SNAPSHOT_FILE"
  echo "SET session_replication_role = DEFAULT;"
  echo "COMMIT;"
} | "${PSQL_CMD[@]}" > /dev/null

echo ""
echo " [실행 후] dev DB row count:"
"${PSQL_CMD[@]}" -tAc "
SELECT format('   %-22s %5s', t, count) FROM (
  SELECT 'members'             AS t, count(*)::text AS count FROM members
  UNION ALL SELECT 'tracks',              count(*)::text FROM tracks
  UNION ALL SELECT 'records',             count(*)::text FROM records
  UNION ALL SELECT 'courses',             count(*)::text FROM courses
  UNION ALL SELECT 'course_drafts',       count(*)::text FROM course_drafts
  UNION ALL SELECT 'course_district',     count(*)::text FROM course_district
  UNION ALL SELECT 'course_bookmark',     count(*)::text FROM course_bookmark
  UNION ALL SELECT 'challenges',          count(*)::text FROM challenges
  UNION ALL SELECT 'member_record_stats', count(*)::text FROM member_record_stats
  UNION ALL SELECT 'orders',              count(*)::text FROM orders
) s;
"

echo ""
echo "==================================================================="
echo " 복원 완료"
echo "==================================================================="

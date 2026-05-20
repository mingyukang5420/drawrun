#!/bin/bash
# snapshot.sql 갱신.
#
# 흐름: 기존 snapshot.sql → snapshot.sql.bak 으로 백업 → 새로 dump → 변경 요약 출력.
# DB 를 직접 조작해서 시연 기준 상태를 바꾼 뒤 그 결과를 snapshot 으로 굳히는 용도.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
OUT_FILE="$SCRIPT_DIR/snapshot.sql"
BAK_FILE="$SCRIPT_DIR/snapshot.sql.bak"

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

if [ ! -f "$OUT_FILE" ]; then
  echo "ERROR: snapshot.sql 이 없습니다." >&2
  echo "       최초 1회는 dump.sh 를 먼저 실행하세요." >&2
  exit 1
fi

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
echo " snapshot.sql 갱신 시작"
echo "   source: $DEV_DB_USERNAME@$DEV_DB_HOST:$DEV_DB_PORT/$DEV_DB_NAME"
echo "==================================================================="

# 기존 파일을 .bak 으로 백업 (덮어쓰기). update 실패해도 원본 보존.
cp "$OUT_FILE" "$BAK_FILE"
echo " 백업 생성: $(basename "$BAK_FILE")"

# 임시 파일에 먼저 쓴 뒤 mv — dump 실패 시 snapshot.sql 깨지지 않게.
TMP_FILE="$OUT_FILE.tmp.$$"
trap 'rm -f "$TMP_FILE"' EXIT

docker exec -e PGPASSWORD="$DEV_DB_PASSWORD" "$LOCAL_PG_CONTAINER" \
  pg_dump "${PG_DUMP_ARGS[@]}" > "$TMP_FILE"

mv "$TMP_FILE" "$OUT_FILE"

OLD_COUNT=$(grep -c "^INSERT INTO " "$BAK_FILE" || true)
NEW_COUNT=$(grep -c "^INSERT INTO " "$OUT_FILE" || true)
DIFF=$((NEW_COUNT - OLD_COUNT))
OLD_SIZE=$(wc -c < "$BAK_FILE" | tr -d ' ')
NEW_SIZE=$(wc -c < "$OUT_FILE" | tr -d ' ')

echo ""
echo "==================================================================="
echo " 완료: $OUT_FILE"
printf "   INSERT 문: %d → %d  (%+d)\n" "$OLD_COUNT" "$NEW_COUNT" "$DIFF"
printf "   파일 크기: %d → %d bytes\n" "$OLD_SIZE" "$NEW_SIZE"
echo "==================================================================="
echo ""
echo " 테이블별 변화 (INSERT 문 기준):"
for t in "${TABLES[@]}"; do
  TABLE_NAME="${t#public.}"
  OLD_T=$(grep -c "^INSERT INTO public.${TABLE_NAME} " "$BAK_FILE" || true)
  NEW_T=$(grep -c "^INSERT INTO public.${TABLE_NAME} " "$OUT_FILE" || true)
  DIFF_T=$((NEW_T - OLD_T))
  if [ "$DIFF_T" -ne 0 ]; then
    printf "   %-22s %5d → %5d  (%+d)\n" "$TABLE_NAME" "$OLD_T" "$NEW_T" "$DIFF_T"
  else
    printf "   %-22s %5d (no change)\n" "$TABLE_NAME" "$NEW_T"
  fi
done

echo ""
echo " 이전 버전은 snapshot.sql.bak 에 보관됨 (rollback 필요 시 mv 로 되돌릴 것)."

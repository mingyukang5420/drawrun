#!/bin/bash
# dev 시연용 mockup 데이터 원터치 적재.
#
# dev backend(https://k14a103.p.ssafy.io/api) 와 dev DB(직접 접속) 를 사용한다.
# OSM/districts 는 dev 에 이미 적재되어 있다는 전제 (mock-loader 가 osm_ways 좌표만 읽음).
#
# 흐름:
#   1) signup (20명)              ← dev /v1/auth/signup
#   2) challenges 6쌍 생성        ← dev /v1/call/test/pipeline (AI 호출, 수십 초 × 6)
#   3) challenges 시간 조작       ← dev DB UPDATE
#   4) CourseDraft 96개           ← 네이버 정적 지도 PNG + dev /v1/editor
#   5) RunningRecord ~192개       ← dev /v1/run/end (similarity_score 자동 계산)
#
# 필요한 .env: data/mock-loader/.env  (.env.example 참고)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$SCRIPT_DIR/mock-loader"
ENV_FILE="$MOCK_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE 가 없습니다. .env.example 을 복사해 채워주세요." >&2
  exit 1
fi

echo "==================================================================="
echo " dev mockup 적재 시작"
echo "==================================================================="

# 한글 경로를 docker --env-file 이 못 읽는 문제 회피.
# .env 는 마운트된 /app/.env 를 config.py 의 load_dotenv 가 직접 로드한다.
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$MOCK_DIR:/app" \
  -w /app \
  python:3.11-slim \
  bash -c "pip install -r requirements.txt -q && python -m loader.load"

echo ""
echo "==================================================================="
echo " 완료"
echo "==================================================================="
echo " 시연 로그인 계정: demo01 ~ demo20 / password1!"

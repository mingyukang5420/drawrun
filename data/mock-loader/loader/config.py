"""mock-loader 환경 설정.

기존(local DB direct INSERT) → 신규(dev backend API 호출) 로 전환됨.
시연 데이터를 dev 서버 정상 비즈니스 로직을 통해 만든다 (이미지 자동 저장 + walkable 검증 통과 자동).

DB 직접 접속은 챌린지 시간 조작 (DB UPDATE) 한 곳에만 사용된다.
"""

import os
from pathlib import Path

from dotenv import load_dotenv


def _load_env() -> None:
    here = Path(__file__).resolve().parent.parent  # mock-loader/
    candidates = [here / ".env", here.parent / "osm-loader" / ".env"]
    for c in candidates:
        if c.exists():
            load_dotenv(c, encoding="utf-8", override=False)


_load_env()


# ----- dev backend API -----
DEV_API_BASE_URL = os.environ.get("DEV_API_BASE_URL", "https://k14a103.p.ssafy.io/api")
TEST_KEY = os.environ["TEST_KEY"]


# ----- dev DB (챌린지 시간 UPDATE 전용) -----
def db_config() -> dict:
    return {
        "host": os.environ["DEV_DB_HOST"],
        "port": int(os.environ.get("DEV_DB_PORT", "5432")),
        "dbname": os.environ["DEV_DB_NAME"],
        "user": os.environ["DEV_DB_USERNAME"],
        "password": os.environ["DEV_DB_PASSWORD"],
    }


# ----- 시연 데이터 규모 -----
NUM_MEMBERS = 20
NUM_CHALLENGE_PAIRS = 6      # = 12개 챌린지. 진행중 1쌍 + 과거 5쌍
NUM_DRAFTS_PER_CHALLENGE = 8 # 챌린지당 CourseDraft 수 (12 × 8 = 96)
NUM_RECORDS_PER_DRAFT = 2    # CourseDraft 당 평균 RunningRecord 수

DEMO_PASSWORD = "password1!"  # 시연 통일 비밀번호 (signup API 통과 길이 8~20)


# ----- 챌린지 시간 분포 -----
# 가장 늦은 1쌍 = 이번 주 진행 중, 나머지 = 1주씩 거슬러 올라간 과거.
CHALLENGE_DURATION_DAYS = 7

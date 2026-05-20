"""DB 접속 정보 + 시연 데이터 규모 상수.

osm-loader 와 같은 .env 형식(POSTGRES_*)을 공유한다 — setup-all.sh 가
data/osm-loader/.env 를 그대로 export 해서 넘긴다.
"""

import os
from pathlib import Path

from dotenv import load_dotenv


def load_db_config() -> dict:
    """psycopg2.connect() 에 그대로 넘길 수 있는 dict 반환.

    setup-all.sh 가 환경변수로 주입하지만, 직접 실행할 때를 위해
    mock-loader/.env 또는 osm-loader/.env 도 탐색한다.
    """
    here = Path(__file__).resolve().parent.parent

    for candidate in (here / ".env", here.parent / "osm-loader" / ".env"):
        if candidate.exists():
            load_dotenv(candidate, encoding="utf-8", override=False)
            break

    return {
        "host": os.environ["POSTGRES_HOST"],
        "port": int(os.environ["POSTGRES_PORT"]),
        "dbname": os.environ["POSTGRES_DB"],
        "user": os.environ["POSTGRES_USER"],
        "password": os.environ["POSTGRES_PASSWORD"],
    }


# ----- 시연 데이터 규모 (소형) -----
# 챌린지가 메인이라 챌린지 관련 비중을 강조한다.
NUM_MEMBERS = 20
NUM_CHALLENGE_PAIRS = 4          # EASY+HARD 쌍 → 총 challenges = 8
NUM_TRACKS = 50
NUM_COURSE_DRAFTS = 100
NUM_RECORDS = 300
NUM_COURSES = 15
NUM_BOOKMARKS = 50

# 시연용 통일 비밀번호 (BCrypt 로 해시되어 저장됨)
DEMO_PASSWORD = "password1!"

"""환경변수에서 DB 접속 정보를 로드한다."""
import os
from pathlib import Path

from dotenv import load_dotenv


def load_db_config() -> dict:
    """프로젝트 루트의 .env를 읽어 psycopg2.connect()에 그대로 넘길 수 있는 dict를 반환한다.

    .env 또는 환경변수에 다음 5개 키가 모두 있어야 한다:
        POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD

    누락 시 KeyError로 실패 — 외부 입력 경계이므로 명시적 실패가 안전.
    """
    project_root = Path(__file__).resolve().parent.parent
    load_dotenv(project_root / ".env")

    return {
        "host": os.environ["POSTGRES_HOST"],
        "port": int(os.environ["POSTGRES_PORT"]),
        "dbname": os.environ["POSTGRES_DB"],
        "user": os.environ["POSTGRES_USER"],
        "password": os.environ["POSTGRES_PASSWORD"],
    }

"""dev DB 접속. 챌린지 시간 UPDATE + OSM walkable 좌표 조회에 사용.

mock 데이터 INSERT 자체는 backend API 가 처리하므로 DB 직접 INSERT 는 거의 없다.
"""

import logging

import psycopg2

from loader.config import db_config

logger = logging.getLogger(__name__)


def get_connection():
    return psycopg2.connect(**db_config())


def count(conn, table: str) -> int:
    with conn.cursor() as cur:
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        return cur.fetchone()[0]


# OSM/districts 는 절대 건드리지 않는다. 그 외 mock 도메인 테이블만 비운다.
# FK 의존성 역순 + CASCADE 로 한 번에 처리.
_MOCK_TABLES_TO_WIPE = [
    "course_bookmark",
    "course_district",         # courses FK
    "member_record_stats",
    "records",
    "courses",
    "course_drafts",
    "tracks",
    "challenges",
    "members",
]


def wipe_mock_tables(conn) -> None:
    """mock 도메인 테이블 전체를 비운다. OSM/districts 는 절대 보존.

    챌린지 이미지/트랙 썸네일 PNG 파일은 dev 디스크에 남아있지만 (mock-loader 권한 밖),
    DB row 가 없어졌으므로 시연에는 영향 없다.
    """
    tables = ", ".join(_MOCK_TABLES_TO_WIPE)
    logger.info("TRUNCATE 대상: %s", tables)
    with conn.cursor() as cur:
        cur.execute(f"TRUNCATE {tables} RESTART IDENTITY CASCADE")
    conn.commit()
    logger.info("mock 테이블 TRUNCATE 완료")

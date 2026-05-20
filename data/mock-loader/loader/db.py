"""DB 연결 + TRUNCATE 헬퍼.

OSM/districts 는 절대 건드리지 않는다 — 시연 셋업이 OSM 재적재를
의도치 않게 트리거하지 않도록 mock 테이블 화이트리스트로 관리.
"""

import logging

import psycopg2

logger = logging.getLogger(__name__)

# FK 의존성 역순으로 TRUNCATE. RESTART IDENTITY 로 시퀀스도 초기화한다.
# CASCADE 는 안전망 — 위에서 아래 순서가 맞다면 굳이 필요 없지만 누락 방어용.
MOCK_TABLES_IN_TRUNCATE_ORDER = [
    "course_bookmark",
    "member_record_stats",
    "records",
    "courses",
    "course_drafts",
    "tracks",
    "challenges",
    "members",
]


def get_connection(cfg: dict):
    return psycopg2.connect(**cfg)


def truncate_mock_tables(conn) -> None:
    """mock 데이터 테이블만 비운다. OSM/districts 는 보존."""
    tables = ", ".join(MOCK_TABLES_IN_TRUNCATE_ORDER)
    logger.info("TRUNCATE 시작: %s", tables)
    with conn.cursor() as cur:
        cur.execute(f"TRUNCATE {tables} RESTART IDENTITY CASCADE")
    conn.commit()
    logger.info("TRUNCATE 완료")


def count(conn, table: str) -> int:
    with conn.cursor() as cur:
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        return cur.fetchone()[0]

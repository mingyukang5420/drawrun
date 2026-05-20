"""시연용 mockup 데이터 적재 진입점.

실행 전제:
- OSM/districts 가 이미 적재되어 있어야 한다 (osm_ways_split 필요).
- setup-all.sh 를 거쳐 호출되거나, 직접 `python -m loader.load` 로 실행.

순서:
1. TRUNCATE (mock 테이블만, OSM/districts 보존)
2. members → tracks → challenges → course_drafts → records → courses → bookmarks → record_stats
3. 최종 row count 출력으로 검증
"""

import logging
import sys

from loader.bookmarks import insert_bookmarks
from loader.challenges import insert_challenges
from loader.config import load_db_config
from loader.coursedrafts import insert_course_drafts
from loader.courses import insert_courses
from loader.db import (
    MOCK_TABLES_IN_TRUNCATE_ORDER,
    count,
    get_connection,
    truncate_mock_tables,
)
from loader.members import insert_members
from loader.records import insert_records
from loader.recordstats import insert_member_record_stats
from loader.tracks import insert_tracks

logger = logging.getLogger(__name__)


def _verify_prerequisites(conn) -> None:
    """OSM/districts 가 비어있으면 mock 적재 의미가 없다 — 명시적 실패."""
    for table in ("osm_ways_split", "districts"):
        n = count(conn, table)
        if n == 0:
            raise RuntimeError(
                f"{table} 가 비어있습니다. run_loader.sh 로 OSM/districts 를 먼저 적재하세요."
            )
        logger.info("전제 확인: %s = %d 행", table, n)


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    cfg = load_db_config()
    logger.info("DB 연결 (host=%s db=%s)", cfg["host"], cfg["dbname"])
    conn = get_connection(cfg)

    try:
        _verify_prerequisites(conn)
        truncate_mock_tables(conn)

        member_ids = insert_members(conn)
        track_ids = insert_tracks(conn)
        challenges = insert_challenges(conn)
        drafts = insert_course_drafts(conn, member_ids, track_ids, challenges)
        record_buckets = insert_records(conn, member_ids, track_ids, challenges, drafts)
        course_ids = insert_courses(conn, record_buckets)
        insert_bookmarks(conn, member_ids, course_ids)
        insert_member_record_stats(conn)

        logger.info("=" * 60)
        logger.info("적재 완료 — 최종 row count:")
        for table in reversed(MOCK_TABLES_IN_TRUNCATE_ORDER):
            logger.info("  %-22s %d", table, count(conn, table))
        logger.info("=" * 60)
    except Exception:
        conn.rollback()
        logger.exception("mockup 적재 실패 — 롤백")
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()

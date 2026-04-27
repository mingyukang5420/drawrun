"""OSM 적재 진입점.

흐름:
    1. .env 로드 (config.load_db_config)
    2. DB 연결
    3. Overpass API 호출 (fetch_overpass)
    4. 응답 파싱 (parse_response) — way/crossing 분리, geometry 부족 way 제거
    5. osm_ways 일괄 INSERT (batch=500)
    6. osm_crossings 일괄 INSERT (batch=500)
    7. 적재 후 SELECT COUNT(*)로 실제 적재 건수 로그

실행: python -m loader.main
"""
import logging

from loader.config import load_db_config
from loader.db import get_connection, insert_crossings_batch, insert_ways_batch
from loader.overpass_client import fetch_overpass
from loader.parser import parse_response

logger = logging.getLogger(__name__)


def _count(conn, table: str) -> int:
    with conn.cursor() as cur:
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        return cur.fetchone()[0]


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    cfg = load_db_config()
    logger.info("DB 연결 (host=%s db=%s)", cfg["host"], cfg["dbname"])
    conn = get_connection(cfg)
    try:
        data = fetch_overpass()
        ways, crossings = parse_response(data)

        logger.info("ways INSERT 시작 (대상=%d)", len(ways))
        insert_ways_batch(conn, ways)
        logger.info("crossings INSERT 시작 (대상=%d)", len(crossings))
        insert_crossings_batch(conn, crossings)

        ways_count = _count(conn, "osm_ways")
        crossings_count = _count(conn, "osm_crossings")
        logger.info(
            "적재 완료: osm_ways=%d, osm_crossings=%d",
            ways_count, crossings_count,
        )
    finally:
        conn.close()


if __name__ == "__main__":
    main()

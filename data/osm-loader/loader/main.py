"""OSM 적재 진입점.

흐름:
    1. .env 로드 (config.load_db_config)
    2. DB 연결
    3. 지역 목록 순회
       a. Overpass API 호출 (fetch_overpass)
       b. 응답 파싱 (parse_response) — way/crossing 분리, geometry 부족 way 제거
       c. Open Elevation API 호출 → 고도값 부착 (attach_elevation)
       d. osm_ways 일괄 INSERT (고도 컬럼 포함, batch=500)
       e. osm_crossings 일괄 INSERT (batch=500)
    4. 적재 후 SELECT COUNT(*)로 실제 적재 건수 로그

실행: python -m loader.main
"""

import logging

from loader.config import load_db_config
from loader.db import get_connection, insert_crossings_batch, insert_ways_batch
from loader.elevation_client import attach_elevation
from loader.overpass_client import fetch_overpass
from loader.parser import parse_response

logger = logging.getLogger(__name__)

# ── 적재 대상 지역 목록 ────────────────────────────────
# 지역 추가 시 여기에만 추가하면 됨
DISTRICTS = [
    "마포구",
    "강남구",
]


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
        for district in DISTRICTS:
            logger.info("=" * 50)
            logger.info("[%s] 적재 시작", district)
            logger.info("=" * 50)

            # 1. Overpass API 호출
            data = fetch_overpass(district)
            ways, crossings = parse_response(data)

            # 2. 고도값 부착
            logger.info("[%s] Open Elevation API 고도값 부착 중...", district)
            ways = attach_elevation(ways)

            # 3. DB INSERT
            logger.info("[%s] ways INSERT 시작 (대상=%d)", district, len(ways))
            insert_ways_batch(conn, ways)

            logger.info(
                "[%s] crossings INSERT 시작 (대상=%d)", district, len(crossings)
            )
            insert_crossings_batch(conn, crossings)

            logger.info("[%s] 적재 완료", district)

        # 최종 건수 확인
        ways_count = _count(conn, "osm_ways")
        crossings_count = _count(conn, "osm_crossings")
        logger.info(
            "전체 적재 완료: osm_ways=%d, osm_crossings=%d",
            ways_count,
            crossings_count,
        )
    finally:
        conn.close()


if __name__ == "__main__":
    main()

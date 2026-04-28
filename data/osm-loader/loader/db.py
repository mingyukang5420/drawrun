"""DB 연결 및 일괄 INSERT 함수."""
import logging
from typing import Iterator

import psycopg2

logger = logging.getLogger(__name__)


def get_connection(cfg: dict):
    """psycopg2.connect 래퍼. cfg는 load_db_config()의 반환 dict."""
    return psycopg2.connect(**cfg)


_INSERT_WAY = """
INSERT INTO osm_ways (
    osm_id, highway, name, geom,
    foot, access, oneway,
    bridge, tunnel, indoor, layer,
    surface, lit, sidewalk
) VALUES (
    %s, %s, %s, ST_GeomFromText(%s, 4326),
    %s, %s, %s,
    %s, %s, %s, %s,
    %s, %s, %s
)
ON CONFLICT (osm_id) DO NOTHING
"""

_INSERT_CROSSING = """
INSERT INTO osm_crossings (osm_id, crossing, has_signals, geom)
VALUES (%s, %s, %s, ST_GeomFromText(%s, 4326))
ON CONFLICT (osm_id) DO NOTHING
"""


def _chunked(items: list, size: int) -> Iterator[list]:
    for i in range(0, len(items), size):
        yield items[i:i + size]


def insert_ways_batch(conn, ways: list[dict], batch_size: int = 500) -> int:
    """ways 리스트를 batch_size씩 끊어 INSERT. 처리(시도)한 행 수를 반환.

    각 dict는 parser.parse_way 출력 형식이어야 한다:
        osm_id, highway, name, geom_wkt, foot, access, oneway,
        bridge, tunnel, indoor, layer, surface, lit, sidewalk

    ON CONFLICT (osm_id) DO NOTHING 이므로 재실행해도 중복 적재되지 않는다.
    실제 적재된 행 수는 ON CONFLICT로 스킵될 수 있어 시도 건수와 다를 수 있음 →
    최종 적재 건수는 SELECT COUNT(*)로 별도 확인.
    """
    total = 0
    with conn.cursor() as cur:
        for chunk in _chunked(ways, batch_size):
            params = [
                (
                    w["osm_id"], w["highway"], w["name"], w["geom_wkt"],
                    w["foot"], w["access"], w["oneway"],
                    w["bridge"], w["tunnel"], w["indoor"], w["layer"],
                    w["surface"], w["lit"], w["sidewalk"],
                )
                for w in chunk
            ]
            cur.executemany(_INSERT_WAY, params)
            conn.commit()
            total += len(chunk)
            logger.info("ways batch processed: %d (total %d)", len(chunk), total)
    return total


def insert_crossings_batch(conn, crossings: list[dict], batch_size: int = 500) -> int:
    """crossings 리스트를 batch_size씩 끊어 INSERT. 처리(시도)한 행 수를 반환.

    각 dict는 parser.parse_node 출력 형식: osm_id, crossing, has_signals, geom_wkt.
    """
    total = 0
    with conn.cursor() as cur:
        for chunk in _chunked(crossings, batch_size):
            params = [
                (c["osm_id"], c["crossing"], c["has_signals"], c["geom_wkt"])
                for c in chunk
            ]
            cur.executemany(_INSERT_CROSSING, params)
            conn.commit()
            total += len(chunk)
            logger.info("crossings batch processed: %d (total %d)", len(chunk), total)
    return total

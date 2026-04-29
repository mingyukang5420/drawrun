"""고도값 0.0 노드 재적재 스크립트.

504 타임아웃으로 0.0 대체된 노드만 Open Elevation API 재요청 후 UPDATE.
한강변 등 실제 0m 지점은 재요청해도 0.0이 유지되며 UPDATE 스킵된다.

흐름:
    1. osm_ways에서 elev=0.0 노드를 가진 way 조회
    2. 0.0 노드 좌표만 추출 (중복 제거)
    3. Open Elevation API 재요청
    4. 값이 바뀐 way만 elevation_nodes UPDATE + 파생 지표 재계산

실행: python -m loader.refill_elevation
"""

import json
import logging
import time

import psycopg2

from loader.config import load_db_config
from loader.elevation_client import (
    BATCH_SIZE,
    ELEVATION_API,
    calc_elevation_stats,
    fetch_elevation_batch,
)

logger = logging.getLogger(__name__)


def get_connection(cfg: dict):
    return psycopg2.connect(**cfg)


def fetch_zero_ways(conn) -> list[dict]:
    """elevation_nodes 안에 elev=0.0인 노드가 하나라도 있는 way 반환."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT osm_id, elevation_nodes
            FROM osm_ways
            WHERE elevation_nodes IS NOT NULL
              AND EXISTS (
                SELECT 1
                FROM jsonb_array_elements(elevation_nodes) AS n
                WHERE (n->>'elev')::float = 0.0
              )
        """)
        rows = cur.fetchall()

    result = [
        {
            "osm_id": osm_id,
            "nodes": nodes if isinstance(nodes, list) else json.loads(nodes),
        }
        for osm_id, nodes in rows
    ]
    logger.info("0.0 노드 포함 way 수: %d", len(result))
    return result


def refetch_elevations(ways: list[dict]) -> dict[tuple, float]:
    """0.0인 노드 좌표만 추출 (중복 제거) 후 재요청. key=(lat, lng) -> elev"""
    zero_coords: dict[tuple, None] = {}
    for way in ways:
        for n in way["nodes"]:
            if n["elev"] == 0.0:
                key = (round(n["lat"], 7), round(n["lng"], 7))
                zero_coords[key] = None

    coord_list = [{"lat": k[0], "lng": k[1]} for k in zero_coords]
    logger.info("재요청 대상 노드 수: %d (중복 제거)", len(coord_list))

    elev_map: dict[tuple, float] = {}
    for i in range(0, len(coord_list), BATCH_SIZE):
        batch = coord_list[i : i + BATCH_SIZE]
        elevs = fetch_elevation_batch(batch)
        for coord, elev in zip(batch, elevs):
            elev_map[(round(coord["lat"], 7), round(coord["lng"], 7))] = elev

        success = sum(1 for e in elevs if e != 0.0)
        logger.info(
            "재요청 %d/%d — 성공: %d, 여전히 0.0: %d",
            min(i + BATCH_SIZE, len(coord_list)),
            len(coord_list),
            success,
            len(elevs) - success,
        )
        time.sleep(0.3)

    return elev_map


def update_ways(conn, ways: list[dict], elev_map: dict[tuple, float]) -> int:
    """0.0 노드를 재요청 결과로 교체 후 UPDATE. 업데이트된 행 수 반환.

    여전히 0.0이면 changed=False로 스킵 (한강변 등 실제 0m 지점).
    """
    updated = 0
    with conn.cursor() as cur:
        for way in ways:
            new_nodes = []
            changed = False
            for n in way["nodes"]:
                if n["elev"] == 0.0:
                    key = (round(n["lat"], 7), round(n["lng"], 7))
                    new_elev = elev_map.get(key, 0.0)
                    if new_elev != 0.0:
                        changed = True
                    new_nodes.append({**n, "elev": new_elev})
                else:
                    new_nodes.append(n)

            if not changed:
                continue

            gain, avg_grade = calc_elevation_stats(new_nodes)
            cur.execute(
                """
                UPDATE osm_ways
                SET
                    elevation_nodes  = %s::jsonb,
                    elevation_gain   = %s,
                    avg_uphill_grade = %s
                WHERE osm_id = %s
            """,
                (
                    json.dumps(new_nodes, ensure_ascii=False),
                    gain,
                    avg_grade,
                    way["osm_id"],
                ),
            )
            updated += 1

        conn.commit()

    logger.info("UPDATE 완료: %d개 way", updated)
    return updated


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    cfg = load_db_config()
    logger.info("DB 연결 (host=%s db=%s)", cfg["host"], cfg["dbname"])
    conn = get_connection(cfg)

    try:
        ways = fetch_zero_ways(conn)
        if not ways:
            logger.info("0.0 노드 없음. 재적재 불필요.")
            return

        elev_map = refetch_elevations(ways)
        updated = update_ways(conn, ways, elev_map)

        with conn.cursor() as cur:
            cur.execute("""
                SELECT COUNT(*) FROM osm_ways
                WHERE elevation_nodes IS NOT NULL
                  AND EXISTS (
                    SELECT 1 FROM jsonb_array_elements(elevation_nodes) n
                    WHERE (n->>'elev')::float = 0.0
                  )
            """)
            remaining = cur.fetchone()[0]

        logger.info(
            "완료: 업데이트 %d개 way, 잔여 0.0 way: %d개 (한강변 등 실제 0m 포함)",
            updated,
            remaining,
        )

    finally:
        conn.close()


if __name__ == "__main__":
    main()

"""고도값 0.0 노드 재적재 스크립트.

504 타임아웃으로 0.0 대체된 노드만 Open Elevation API 재요청 후 UPDATE.

흐름:
    1. osm_ways에서 elev=0.0 노드를 가진 way 조회
    2. 해당 노드 좌표만 추출 (중복 제거)
    3. Open Elevation API 재요청
    4. elevation_nodes UPDATE + elevation_gain, avg_uphill_grade 재계산

실행: python -m loader.refill_elevation
"""

import json
import logging
import math
import time

import psycopg2
import requests

from loader.config import load_db_config

logger = logging.getLogger(__name__)

ELEVATION_API = "https://api.open-elevation.com/api/v1/lookup"
BATCH_SIZE = 100


# ── 유틸 ──────────────────────────────────────────────


def _haversine(a: dict, b: dict) -> float:
    R = 6_371_000
    lat1, lng1 = math.radians(a["lat"]), math.radians(a["lng"])
    lat2, lng2 = math.radians(b["lat"]), math.radians(b["lng"])
    dlat, dlng = lat2 - lat1, lng2 - lng1
    x = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    )
    return R * 2 * math.asin(math.sqrt(x))


def _fetch_elevation_batch(coords: list[dict]) -> list[float]:
    locations = [{"latitude": c["lat"], "longitude": c["lng"]} for c in coords]
    try:
        resp = requests.post(
            ELEVATION_API,
            json={"locations": locations},
            timeout=30,
        )
        resp.raise_for_status()
        return [r.get("elevation", 0.0) for r in resp.json().get("results", [])]
    except Exception as exc:
        logger.warning("고도 API 실패: %s → 0.0 유지", exc)
        return [0.0] * len(coords)


def _calc_elevation_stats(nodes: list[dict]) -> tuple[float, float]:
    """elevation_gain, avg_uphill_grade 계산."""
    gain = 0.0
    uphill_grades = []
    for i in range(len(nodes) - 1):
        a, b = nodes[i], nodes[i + 1]
        dist = _haversine(a, b)
        if dist < 1:
            continue
        diff = b["elev"] - a["elev"]
        grade = (diff / dist) * 100
        if diff > 0:
            gain += diff
            uphill_grades.append(grade)
    avg_grade = sum(uphill_grades) / len(uphill_grades) if uphill_grades else 0.0
    return round(gain, 2), round(avg_grade, 4)


# ── Step 1: 0.0 노드를 가진 way 조회 ──────────────────


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

    result = []
    for osm_id, nodes in rows:
        if isinstance(nodes, str):
            nodes = json.loads(nodes)
        result.append({"osm_id": osm_id, "nodes": nodes})

    logger.info("0.0 노드 포함 way 수: %d", len(result))
    return result


# ── Step 2: 0.0 노드 좌표 수집 (중복 제거) ────────────


def collect_zero_coords(ways: list[dict]) -> dict[tuple, None]:
    """0.0인 노드 좌표 집합 반환. key=(lat, lng)"""
    coords = {}
    for way in ways:
        for n in way["nodes"]:
            if n["elev"] == 0.0:
                key = (round(n["lat"], 7), round(n["lng"], 7))
                coords[key] = None
    logger.info("재요청 대상 노드 수: %d (중복 제거)", len(coords))
    return coords


# ── Step 3: 고도 재요청 ────────────────────────────────


def refetch_elevations(zero_coords: dict) -> dict[tuple, float]:
    """0.0 노드 좌표만 재요청. key=(lat, lng) → elev"""
    coord_list = [{"lat": k[0], "lng": k[1]} for k in zero_coords]
    elev_map: dict[tuple, float] = {}

    for i in range(0, len(coord_list), BATCH_SIZE):
        batch = coord_list[i : i + BATCH_SIZE]
        elevs = _fetch_elevation_batch(batch)
        for coord, elev in zip(batch, elevs):
            key = (round(coord["lat"], 7), round(coord["lng"], 7))
            elev_map[key] = elev

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


# ── Step 4: elevation_nodes UPDATE ────────────────────


def update_ways(conn, ways: list[dict], elev_map: dict[tuple, float]) -> int:
    """0.0 노드를 재요청 결과로 교체 후 UPDATE. 업데이트된 행 수 반환."""
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
                continue  # 여전히 0.0이면 스킵

            gain, avg_grade = _calc_elevation_stats(new_nodes)
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


# ── 실행 ──────────────────────────────────────────────


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    cfg = load_db_config()
    logger.info("DB 연결 (host=%s db=%s)", cfg["host"], cfg["dbname"])
    conn = get_connection(cfg)

    try:
        # 1. 0.0 노드 포함 way 조회
        ways = fetch_zero_ways(conn)
        if not ways:
            logger.info("0.0 노드 없음. 재적재 불필요.")
            return

        # 2. 0.0 좌표 수집
        zero_coords = collect_zero_coords(ways)

        # 3. 고도 재요청
        elev_map = refetch_elevations(zero_coords)

        # 4. DB UPDATE
        updated = update_ways(conn, ways, elev_map)

        # 5. 결과 확인
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
            "재적재 완료: 업데이트 %d개 way, 잔여 0.0 way: %d개", updated, remaining
        )

    finally:
        conn.close()


def get_connection(cfg):
    return psycopg2.connect(**cfg)


if __name__ == "__main__":
    main()

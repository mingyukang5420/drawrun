"""Open Elevation API 클라이언트.

osm_ways 노드 좌표 배열을 받아 고도값을 부착하고
elevation_gain, avg_uphill_grade를 계산해 반환한다.
"""

import logging
import math
import time

import requests

logger = logging.getLogger(__name__)

ELEVATION_API = "https://api.open-elevation.com/api/v1/lookup"
BATCH_SIZE = 100  # 요청당 최대 포인트 수


def _haversine(a: dict, b: dict) -> float:
    """두 좌표 간 거리 (미터). a, b = {"lat": ..., "lng": ...}"""
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
    """좌표 배열의 고도값 반환. 실패 시 0.0으로 대체."""
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
        logger.warning("고도 API 실패: %s → 0.0 대체", exc)
        return [0.0] * len(coords)


def attach_elevation(ways: list[dict]) -> list[dict]:
    """
    파싱된 ways 리스트에 고도 정보를 부착한다.

    입력 (parser.parse_way 출력 형식):
        geom_wkt: "LINESTRING(lng lat, lng lat, ...)"

    출력 (추가 필드):
        elevation_nodes:   [{lng, lat, elev}, ...]
        elevation_gain:    float (m)
        avg_uphill_grade:  float (%)

    처리 흐름:
        1. 모든 way의 노드 좌표 수집 (중복 제거)
        2. Open Elevation API 배치 호출
        3. 각 way에 고도값 부착 + 파생 지표 계산
    """
    # 1. 전체 노드 좌표 수집 (중복 제거)
    all_coords: list[dict] = []
    coord_index: dict[tuple, int] = {}

    for way in ways:
        for node in _parse_linestring(way["geom_wkt"]):
            key = (round(node["lat"], 7), round(node["lng"], 7))
            if key not in coord_index:
                coord_index[key] = len(all_coords)
                all_coords.append(node)

    logger.info("고도 조회 대상 노드 수: %d", len(all_coords))

    # 2. 배치 단위로 고도 요청
    elevations: list[float] = []
    for i in range(0, len(all_coords), BATCH_SIZE):
        batch = all_coords[i : i + BATCH_SIZE]
        elevations.extend(_fetch_elevation_batch(batch))
        logger.info(
            "고도 처리: %d/%d",
            min(i + BATCH_SIZE, len(all_coords)),
            len(all_coords),
        )
        time.sleep(0.3)

    # 고도 맵 생성
    elev_map: dict[tuple, float] = {
        (round(c["lat"], 7), round(c["lng"], 7)): elevations[i]
        for i, c in enumerate(all_coords)
    }

    # 3. 각 way에 고도값 부착 + 파생 지표 계산
    enriched = []
    for way in ways:
        nodes = _parse_linestring(way["geom_wkt"])
        elevation_nodes = [
            {
                "lng": n["lng"],
                "lat": n["lat"],
                "elev": elev_map.get((round(n["lat"], 7), round(n["lng"], 7)), 0.0),
            }
            for n in nodes
        ]

        elevation_gain = 0.0
        uphill_grades: list[float] = []

        for i in range(len(elevation_nodes) - 1):
            a, b = elevation_nodes[i], elevation_nodes[i + 1]
            dist = _haversine(a, b)
            if dist < 1:
                continue
            diff = b["elev"] - a["elev"]
            grade = (diff / dist) * 100
            if diff > 0:
                elevation_gain += diff
                uphill_grades.append(grade)

        enriched.append(
            {
                **way,
                "elevation_nodes": elevation_nodes,
                "elevation_gain": round(elevation_gain, 2),
                "avg_uphill_grade": round(
                    sum(uphill_grades) / len(uphill_grades) if uphill_grades else 0.0,
                    4,
                ),
            }
        )

    return enriched


def _parse_linestring(wkt: str) -> list[dict]:
    """'LINESTRING(lng lat, lng lat, ...)' → [{lng, lat}, ...] 변환."""
    inner = wkt.replace("LINESTRING(", "").rstrip(")")
    result = []
    for pair in inner.split(","):
        lng_str, lat_str = pair.strip().split()
        result.append({"lng": float(lng_str), "lat": float(lat_str)})
    return result

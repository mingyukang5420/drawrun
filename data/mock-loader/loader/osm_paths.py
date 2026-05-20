"""osm_ways 에서 walkable 좌표 시퀀스 추출.

backend EditorService 의 walkable 검증(osm_ways_split 1m buffer 내) 은
osm_ways 의 노드 좌표를 그대로 쓰면 자동 통과한다 (split 이 ways 의 부분집합이라 동일 노드).

길이 500m~5km 범위만 골라 시연용 트랙으로 적합한 분포를 만든다.
"""

import json
import logging
import random

logger = logging.getLogger(__name__)

TRACK_MIN_METERS = 500
TRACK_MAX_METERS = 5000

# editor save 요청 body 의 coordinates 배열은 최대 ~수십 개 정도면 충분.
# 네이버 정적 지도 URL 길이 제한도 고려해 적당히 잘라낸다.
_MAX_NODES = 40


def _thin(points: list[tuple[float, float]], k: int) -> list[tuple[float, float]]:
    if len(points) <= k:
        return points
    step = (len(points) - 1) / (k - 1)
    return [points[min(round(i * step), len(points) - 1)] for i in range(k)]


def pick_walkable_paths(conn, count: int, seed: int = 42) -> list[list[dict]]:
    """반환: count 개의 좌표 시퀀스. 각 시퀀스 = [{lat, lng, order}, ...].

    osm_ways 의 LineString geom 을 GeoJSON 으로 받아 (lng,lat) 시퀀스로 변환,
    editor save 요청 형식에 맞춰 [{lat, lng, order(1-based)}] 로 직렬화한다.
    """
    random.seed(seed)
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT ST_AsGeoJSON(geom)
            FROM osm_ways
            WHERE ST_Length(geom::geography) BETWEEN %s AND %s
            ORDER BY RANDOM()
            LIMIT %s
            """,
            (TRACK_MIN_METERS, TRACK_MAX_METERS, count),
        )
        rows = cur.fetchall()

    if len(rows) < count:
        raise RuntimeError(
            f"osm_ways 에서 {count} 개를 못 뽑음 ({len(rows)} 개만 확보). "
            "OSM 데이터 적재 여부 또는 길이 범위를 확인하세요."
        )

    paths: list[list[dict]] = []
    for (geojson_text,) in rows:
        gj = json.loads(geojson_text)
        coords = gj["coordinates"]  # [[lng, lat], ...]
        thinned = _thin([(c[0], c[1]) for c in coords], _MAX_NODES)
        seq = [{"lat": lat, "lng": lng, "order": idx + 1}
               for idx, (lng, lat) in enumerate(thinned)]
        paths.append(seq)

    logger.info(
        "walkable 좌표 시퀀스 %d 개 추출 완료 (길이 범위 %dm~%dm)",
        len(paths), TRACK_MIN_METERS, TRACK_MAX_METERS,
    )
    return paths

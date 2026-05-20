"""tracks 적재.

osm_ways (split 이전) 에서 LINESTRING 을 골라 ST_Multi 로 MultiLineString 으로 래핑한다.
- 시연 트랙은 러닝 코스 수준의 길이가 필요 → osm_ways_split (교차점 기준 잘게 쪼갠 것)
  대신 osm_ways 를 사용한다. 좌표는 osm_ways_split 의 좌표와 동일하므로
  OsmService.validateAllPointsWalkable (ST_DWithin epsilon buffer) 검증도 자동 통과.
- 길이는 시연용으로 의미 있는 500m~5km 만 추출.
- 거리는 ST_Length(::geography) 로 PostGIS 가 미터 단위로 계산.
"""

import logging

from loader.config import NUM_TRACKS
from loader.image_urls import random_track_image_url

logger = logging.getLogger(__name__)

# 시연 트랙 길이 범위(m). 너무 짧으면 의미 없고, 너무 길면 시연 시각화가 어렵다.
TRACK_MIN_METERS = 500
TRACK_MAX_METERS = 5000

_INSERT_TRACKS = """
INSERT INTO tracks (geom, distance, track_image_url, created_at, updated_at)
SELECT
    ST_Multi(geom)::geometry(MultiLineString, 4326),
    ST_Length(geom::geography),
    %s,
    NOW(), NOW()
FROM (
    SELECT geom
    FROM osm_ways
    WHERE ST_Length(geom::geography) BETWEEN %s AND %s
    ORDER BY RANDOM()
    LIMIT 1
) s
RETURNING track_id
"""


def insert_tracks(conn) -> list[int]:
    track_ids: list[int] = []
    with conn.cursor() as cur:
        for _ in range(NUM_TRACKS):
            cur.execute(
                _INSERT_TRACKS,
                (random_track_image_url(), TRACK_MIN_METERS, TRACK_MAX_METERS),
            )
            row = cur.fetchone()
            if row is None:
                raise RuntimeError(
                    f"osm_ways 에서 {TRACK_MIN_METERS}~{TRACK_MAX_METERS}m 범위 LINESTRING 을 "
                    "추출하지 못했습니다. OSM 데이터 적재 여부를 확인하세요."
                )
            track_ids.append(row[0])
    conn.commit()
    logger.info(
        "tracks 적재 완료: %d 개 (길이 범위 %dm~%dm)",
        len(track_ids), TRACK_MIN_METERS, TRACK_MAX_METERS,
    )
    return track_ids

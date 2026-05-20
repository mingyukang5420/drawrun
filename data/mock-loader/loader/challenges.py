"""challenges 적재.

- EASY/HARD 한 쌍이 같은 groupUUID 를 공유 (실제 스케줄러 동작과 동일)
- 시간 분포: 진행 중 1쌍 + 완료된 과거 (NUM_CHALLENGE_PAIRS - 1) 쌍
- 폴리곤은 알고리즘 생성 (원/사각/별/삼각형 4종 순환)
- polygon_points 는 JSON [[x, y], ...] 형식 — SimilarityService.parsePolygon 호환
"""

import json
import logging
import math
import random
import uuid
from datetime import datetime, timedelta

from loader.config import NUM_CHALLENGE_PAIRS
from loader.image_urls import random_challenge_image_url

logger = logging.getLogger(__name__)


def _circle_polygon(num_points: int = 36) -> list[list[float]]:
    return [
        [math.cos(2 * math.pi * i / num_points), math.sin(2 * math.pi * i / num_points)]
        for i in range(num_points)
    ]


def _square_polygon() -> list[list[float]]:
    # 변마다 5개 점 → 총 20개. centroid (0,0).
    pts: list[list[float]] = []
    for t in range(5):
        pts.append([-1.0 + t * 0.5, -1.0])
    for t in range(5):
        pts.append([1.0, -1.0 + t * 0.5])
    for t in range(5):
        pts.append([1.0 - t * 0.5, 1.0])
    for t in range(5):
        pts.append([-1.0, 1.0 - t * 0.5])
    return pts


def _star_polygon(arms: int = 5) -> list[list[float]]:
    # 별 꼭짓점 / 안쪽 점 번갈아.
    pts: list[list[float]] = []
    for i in range(arms * 2):
        r = 1.0 if i % 2 == 0 else 0.4
        theta = math.pi / 2 + math.pi * i / arms
        pts.append([r * math.cos(theta), r * math.sin(theta)])
    return pts


def _triangle_polygon() -> list[list[float]]:
    # 정삼각형 + 각 변에 추가 점.
    vertices = [
        [0.0, 1.0],
        [math.cos(math.radians(210)), math.sin(math.radians(210))],
        [math.cos(math.radians(330)), math.sin(math.radians(330))],
    ]
    pts: list[list[float]] = []
    for i in range(3):
        a = vertices[i]
        b = vertices[(i + 1) % 3]
        for t in range(7):
            f = t / 7.0
            pts.append([a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f])
    return pts


_POLYGON_GENERATORS = [_circle_polygon, _square_polygon, _star_polygon, _triangle_polygon]
_TITLE_PREFIX = ["원형", "사각", "별", "삼각"]


_INSERT_CHALLENGE = """
INSERT INTO challenges (
    title, polygon_image_url, started_at, ended_at,
    polygon_points, group_uuid, difficulty,
    created_at, updated_at
) VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
RETURNING challenge_id
"""


def insert_challenges(conn) -> list[dict]:
    """반환값: [{id, started_at, ended_at, group_uuid, difficulty}] — 후속 모듈에서 사용."""
    now = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    # 이번 주 월요일 0시 ~ 일요일 23:59:59 가 진행중 챌린지.
    this_monday = now - timedelta(days=now.weekday())

    rows: list[dict] = []
    with conn.cursor() as cur:
        for pair_idx in range(NUM_CHALLENGE_PAIRS):
            # pair_idx 0 = 진행 중, 그 이후로 한 주씩 과거.
            week_offset = -pair_idx
            started = this_monday + timedelta(weeks=week_offset)
            ended = started + timedelta(days=6, hours=23, minutes=59, seconds=59)

            poly_gen = _POLYGON_GENERATORS[pair_idx % len(_POLYGON_GENERATORS)]
            polygon_json = json.dumps(poly_gen())
            title_prefix = _TITLE_PREFIX[pair_idx % len(_TITLE_PREFIX)]
            group_uuid = str(uuid.uuid4())

            for difficulty in ("EASY", "HARD"):
                title = f"{title_prefix} {difficulty.lower()}"  # 20자 제한
                cur.execute(
                    _INSERT_CHALLENGE,
                    (
                        title,
                        random_challenge_image_url(),
                        started,
                        ended,
                        polygon_json,
                        group_uuid,
                        difficulty,
                    ),
                )
                cid = cur.fetchone()[0]
                rows.append(
                    {
                        "id": cid,
                        "started_at": started,
                        "ended_at": ended,
                        "group_uuid": group_uuid,
                        "difficulty": difficulty,
                    }
                )
    conn.commit()
    ongoing = sum(1 for r in rows if r["ended_at"] >= now)
    logger.info(
        "challenges 적재 완료: 총 %d 개 (진행중 %d / 종료 %d, 쌍 %d)",
        len(rows), ongoing, len(rows) - ongoing, NUM_CHALLENGE_PAIRS,
    )
    return rows

"""RunningRecord 생성 phase — backend /v1/run/end 호출.

각 CourseDraft 에 대해 NUM_RECORDS_PER_DRAFT 개의 챌린지 도전 기록을 만든다.
- course_id      = None
- course_draft_id = draft.id
- challenge_id   = draft 가 속한 챌린지
- runner = **draft 소유자** (backend RecordService.verifyCourseDraftIfEligible 가
            findByIdAndMemberId 로 draft 소유자/러너 일치를 강제하기 때문)

챌린지에 다양한 회원 분포가 필요한 부분은 drafts phase 에서 회원을 분산시키는 것으로 해결됨.

distance 는 좌표 시퀀스에서 haversine 으로 계산 (km 단위, run/end API 명세).
"""

import logging
import random
from datetime import datetime, timedelta
from math import asin, cos, radians, sin, sqrt

from loader.config import NUM_RECORDS_PER_DRAFT
from loader.http_client import create_record, login

logger = logging.getLogger(__name__)

_RECORD_TITLES = [
    "오늘의 러닝", "저녁런", "주말 가볍게", "장거리 도전",
    "야간 산책런", "회복런", "인터벌", "스피드 세션", "한바퀴", "기록 도전",
]


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return 2 * r * asin(sqrt(a))


def _path_distance_km(coords: list[dict]) -> float:
    total = 0.0
    for a, b in zip(coords, coords[1:]):
        total += _haversine_km(a["lat"], a["lng"], b["lat"], b["lng"])
    return total


def _random_start(window_start: datetime, window_end: datetime) -> datetime:
    span = (window_end - window_start).total_seconds()
    return window_start + timedelta(seconds=random.uniform(0, max(span, 1)))


def create_records(members: list[dict], drafts: list[dict]) -> int:
    """각 draft 에 대해 NUM_RECORDS_PER_DRAFT 개의 RunningRecord 를 등록."""
    random.seed(123)
    # 로그인 토큰 캐시 재발급.
    tokens = {m["loginId"]: login(m["loginId"], m["password"]) for m in members}

    created = 0
    for draft in drafts:
        coords = draft["coordinates"]
        if len(coords) < 2:
            continue
        distance_km = _path_distance_km(coords)
        if distance_km <= 0:
            continue

        # challenge 기간 내에서 시작 시점 분포.
        win_start = draft["challenge_started_at"]
        win_end = min(draft["challenge_ended_at"], datetime.now())
        if win_end <= win_start:
            win_end = win_start + timedelta(hours=1)

        # backend 가 draft 소유자만 verify 통과시키므로 러너 = draft 소유자.
        runner_login = draft["memberLoginId"]
        jwt = tokens[runner_login]

        for _ in range(NUM_RECORDS_PER_DRAFT):

            pace_min_per_km = random.uniform(5.0, 7.0)
            running_time_sec = max(int(distance_km * pace_min_per_km * 60), 60)
            calories = max(int(distance_km * 60), 1)
            cadence = random.randint(150, 185)

            started_at = _random_start(win_start, win_end)
            ended_at = started_at + timedelta(seconds=running_time_sec)

            try:
                create_record(
                    jwt,
                    course_id=None,
                    course_draft_id=draft["courseDraftId"],
                    challenge_id=draft["challengeId"],
                    title=random.choice(_RECORD_TITLES),
                    distance_km=round(distance_km, 2),
                    track_image_url=draft["trackImageUrl"],
                    running_time_sec=running_time_sec,
                    avg_pace=round(pace_min_per_km, 2),
                    calories=calories,
                    cadence=cadence,
                    started_at_iso=started_at.strftime("%Y-%m-%dT%H:%M:%S"),
                    ended_at_iso=ended_at.strftime("%Y-%m-%dT%H:%M:%S"),
                    nodes=[{"lat": c["lat"], "lng": c["lng"]} for c in coords],
                )
                created += 1
            except Exception as e:
                logger.warning(
                    "record 생성 실패 (draft=%s, runner=%s): %s",
                    draft["courseDraftId"], runner_login, e,
                )

    logger.info("RunningRecord 생성 완료: %d 개", created)
    return created

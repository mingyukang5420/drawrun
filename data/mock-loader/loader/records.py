"""records (RunningRecord) 적재.

세 종류로 나누어 한 번에 INSERT 한다:
1. 챌린지 도전 (course_draft_id + challenge_id + similarity_score)
2. 일반 CourseDraft 런 (course_draft_id 만)
3. 자유 러닝 (모두 NULL)

Course 런(course_id 채워진 기록) 은 records 적재 후 courses 모듈에서 UPDATE 로 만든다 —
Course.source_record_id 가 record 를 가리키는 순환을 단순화하기 위함.
"""

import logging
import random
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

# 분포 (총 300). NUM_RECORDS 와 합산 일치 — 변경 시 같이 수정.
N_CHALLENGE = 150       # 챌린지 도전 (course_draft_id 사용)
N_DRAFT_ONLY = 80       # 일반 CourseDraft 런
N_FREE = 70             # 자유 러닝 (이후 일부가 Course 런으로 승격됨)

_RECORD_TITLES = [
    "오늘의 러닝", "저녁런", "주말 가볍게", "장거리 도전",
    "야간 산책런", "회복런", "인터벌", "스피드 세션", "한바퀴",
    "기록 도전", "쉬엄쉬엄", "근력 보강런", "땀나는 하루",
]


_INSERT_RECORD = """
INSERT INTO records (
    member_id, course_id, course_draft_id, track_id,
    running_time, avg_pace, calories, cadence,
    is_completed, is_safe, title,
    started_at, ended_at,
    challenge_id, similarity_score,
    created_at, updated_at
) VALUES (
    %s, NULL, %s, %s,
    %s, %s, %s, %s,
    %s, %s, %s,
    %s, %s,
    %s, %s,
    NOW(), NOW()
)
RETURNING record_id
"""


def _load_track_distances(conn, track_ids: list[int]) -> dict[int, float]:
    """tracks 의 distance(m) 조회. running_time 계산 용."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT track_id, distance FROM tracks WHERE track_id = ANY(%s)",
            (track_ids,),
        )
        return {row[0]: float(row[1]) for row in cur.fetchall()}


def _random_started_at(window_start: datetime, window_end: datetime) -> datetime:
    span = (window_end - window_start).total_seconds()
    return window_start + timedelta(seconds=random.uniform(0, max(span, 1)))


def _compute_running_metrics(distance_m: float) -> tuple[int, float, int, int]:
    """distance(m) 기준으로 running_time(s) / avg_pace(min/km) / calories / cadence 산출.

    pace 5~7분/km 정도로 랜덤, 그에 맞춰 running_time 결정.
    """
    pace_min_per_km = random.uniform(5.0, 7.0)
    distance_km = max(distance_m / 1000.0, 0.05)  # 최소 50m
    running_time = int(distance_km * pace_min_per_km * 60)
    # 칼로리: 1km 당 60kcal 가정 → 평범한 60kg 성인 기준 단순화
    calories = int(distance_km * 60)
    cadence = random.randint(150, 185)
    return running_time, round(pace_min_per_km, 2), max(calories, 1), cadence


def insert_records(
    conn,
    member_ids: list[int],
    track_ids: list[int],
    challenges: list[dict],
    course_drafts: list[dict],
) -> dict[str, list[int]]:
    """반환값: {'free': [...], 'draft_only': [...], 'challenge': [...]} 의 record_id 목록.

    courses 모듈에서 'free' 일부를 골라 course_id 를 UPDATE 한다.
    """
    random.seed(123)
    distances = _load_track_distances(conn, track_ids)

    now = datetime.now()
    past_30d_start = now - timedelta(days=30)

    # 챌린지 도전 후보 — challenge_id 채워진 draft 만.
    drafts_with_challenge = [d for d in course_drafts if d["challenge_id"] is not None]
    if not drafts_with_challenge:
        raise RuntimeError("챌린지 연결 course_draft 가 없습니다. coursedrafts 적재를 확인하세요.")
    drafts_general = [d for d in course_drafts if d["challenge_id"] is None]

    challenge_by_id = {c["id"]: c for c in challenges}

    free_ids: list[int] = []
    draft_only_ids: list[int] = []
    challenge_ids: list[int] = []

    with conn.cursor() as cur:
        # 1) 챌린지 도전
        for _ in range(N_CHALLENGE):
            draft = random.choice(drafts_with_challenge)
            challenge = challenge_by_id[draft["challenge_id"]]
            # 시작 시점은 챌린지 기간 내 (이미 종료된 챌린지면 그 기간 내, 진행중이면 시작~now 사이)
            window_start = challenge["started_at"]
            window_end = min(challenge["ended_at"], now)
            if window_end <= window_start:
                window_end = window_start + timedelta(hours=1)
            started_at = _random_started_at(window_start, window_end)
            track_id = draft["track_id"]
            running_time, pace, calories, cadence = _compute_running_metrics(
                distances.get(track_id, 1000.0)
            )
            ended_at = started_at + timedelta(seconds=running_time)
            similarity = round(random.uniform(35.0, 95.0), 2)

            cur.execute(
                _INSERT_RECORD,
                (
                    draft["member_id"],
                    draft["id"],
                    track_id,
                    running_time, pace, calories, cadence,
                    True, True,
                    random.choice(_RECORD_TITLES),
                    started_at, ended_at,
                    challenge["id"], similarity,
                ),
            )
            challenge_ids.append(cur.fetchone()[0])

        # 2) 일반 CourseDraft 런
        for _ in range(N_DRAFT_ONLY):
            draft = random.choice(drafts_general) if drafts_general else random.choice(course_drafts)
            track_id = draft["track_id"]
            running_time, pace, calories, cadence = _compute_running_metrics(
                distances.get(track_id, 1000.0)
            )
            started_at = _random_started_at(past_30d_start, now)
            ended_at = started_at + timedelta(seconds=running_time)
            # 일부는 미완주/위험 — 시연 다양성
            is_completed = random.random() > 0.1
            is_safe = random.random() > 0.05

            cur.execute(
                _INSERT_RECORD,
                (
                    draft["member_id"],
                    draft["id"],
                    track_id,
                    running_time, pace, calories, cadence,
                    is_completed, is_safe,
                    random.choice(_RECORD_TITLES),
                    started_at, ended_at,
                    None, None,
                ),
            )
            draft_only_ids.append(cur.fetchone()[0])

        # 3) 자유 러닝
        for _ in range(N_FREE):
            member_id = random.choice(member_ids)
            track_id = random.choice(track_ids)
            running_time, pace, calories, cadence = _compute_running_metrics(
                distances.get(track_id, 1000.0)
            )
            started_at = _random_started_at(past_30d_start, now)
            ended_at = started_at + timedelta(seconds=running_time)

            cur.execute(
                _INSERT_RECORD,
                (
                    member_id,
                    None,
                    track_id,
                    running_time, pace, calories, cadence,
                    True, True,
                    random.choice(_RECORD_TITLES),
                    started_at, ended_at,
                    None, None,
                ),
            )
            free_ids.append(cur.fetchone()[0])

    conn.commit()
    logger.info(
        "records 적재 완료: 챌린지 %d + draft %d + 자유 %d = %d 개",
        len(challenge_ids), len(draft_only_ids), len(free_ids),
        len(challenge_ids) + len(draft_only_ids) + len(free_ids),
    )
    return {
        "challenge": challenge_ids,
        "draft_only": draft_only_ids,
        "free": free_ids,
    }

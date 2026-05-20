"""course_drafts 적재.

분포(소형):
- 챌린지 FK 채워진 draft: 40 (챌린지 도전 흐름)
- 일반 draft (challenge_id NULL): 60
- 상태: READY 40 / DONE 60 (DONE 중 일부에서 Course 승격됨)
"""

import logging
import random

from loader.config import NUM_COURSE_DRAFTS

logger = logging.getLogger(__name__)

_DIFFICULTIES = ["BEGINNER", "EASY", "NORMAL", "HARD"]
_TITLE_POOL = [
    "한강 새벽런", "남산 둘레길", "올림픽공원 한바퀴", "여의도 트랙",
    "한강공원 야간", "선유도 한바퀴", "월드컵공원 코스", "잠실 호수 한바퀴",
    "응봉산 오르막", "성수동 도시런", "북서울 둘레길", "양재천 산책",
    "마포대교 왕복", "이촌한강공원", "뚝섬 강변로", "성수대교 코스",
]

_INSERT_DRAFT = """
INSERT INTO course_drafts (
    member_id, track_id, title, difficulty, status,
    challenge_id, created_at, updated_at
) VALUES (%s, %s, %s, %s, %s, %s, NOW(), NOW())
RETURNING course_draft_id
"""


def insert_course_drafts(
    conn,
    member_ids: list[int],
    track_ids: list[int],
    challenges: list[dict],
) -> list[dict]:
    """반환값: [{id, member_id, track_id, status, challenge_id}] — records 적재에서 사용."""
    random.seed(42)

    num_with_challenge = 40
    num_done = 60

    challenge_ids = [c["id"] for c in challenges]

    rows: list[dict] = []
    with conn.cursor() as cur:
        for i in range(NUM_COURSE_DRAFTS):
            member_id = random.choice(member_ids)
            track_id = random.choice(track_ids)
            title = random.choice(_TITLE_POOL)
            difficulty = random.choice(_DIFFICULTIES)
            status = "DONE" if i < num_done else "READY"
            challenge_id = random.choice(challenge_ids) if i < num_with_challenge else None

            cur.execute(
                _INSERT_DRAFT,
                (member_id, track_id, title, difficulty, status, challenge_id),
            )
            draft_id = cur.fetchone()[0]
            rows.append(
                {
                    "id": draft_id,
                    "member_id": member_id,
                    "track_id": track_id,
                    "status": status,
                    "challenge_id": challenge_id,
                }
            )
    conn.commit()
    done = sum(1 for r in rows if r["status"] == "DONE")
    with_ch = sum(1 for r in rows if r["challenge_id"] is not None)
    logger.info(
        "course_drafts 적재 완료: %d 개 (DONE %d / READY %d, 챌린지 연결 %d)",
        len(rows), done, len(rows) - done, with_ch,
    )
    return rows

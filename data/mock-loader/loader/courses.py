"""courses 적재 + 일부 records 를 Course 런으로 승격(UPDATE).

흐름:
1. draft_only records 중 NUM_COURSES 개를 source_record 로 골라 Course 생성
2. 그 source_record 의 course_id 를 방금 만든 course 로 UPDATE — 첫 완주 기록 자체가 코스에 매핑된 상태
3. 추가로 free records 중 일부에도 같은 course_id 를 UPDATE → "Course 런" 분포 확보
"""

import logging
import random

from loader.config import NUM_COURSES

logger = logging.getLogger(__name__)

_DIFFICULTIES = ["BEGINNER", "EASY", "NORMAL", "HARD"]
_COURSE_TITLES = [
    "잠수교 야경런", "남산 정상런", "올림픽 그랜드", "한강 노을 코스",
    "여의도 라이트", "성수 카페런", "북서울 둘레", "월드컵 호수",
    "선유도 야경", "응봉 일출런", "이촌강변", "양재천 봄",
    "마포 다리런", "뚝섬 강변", "성수대교 야간",
]

_INSERT_COURSE = """
INSERT INTO courses (
    member_id, source_record_id, title, difficulty,
    completion_score, created_at, updated_at
) VALUES (%s, %s, %s, %s, %s, NOW(), NOW())
RETURNING course_id
"""

_UPDATE_RECORD_COURSE_ID = """
UPDATE records SET course_id = %s WHERE record_id = %s
"""

# 추가로 자유러닝을 Course 런으로 전환 — Course당 평균 2건.
COURSE_RUN_PER_COURSE = 2


def insert_courses(
    conn,
    record_buckets: dict[str, list[int]],
) -> list[int]:
    random.seed(7)
    draft_only = record_buckets["draft_only"][:]
    free = record_buckets["free"][:]
    if len(draft_only) < NUM_COURSES:
        raise RuntimeError(
            f"draft_only records 가 {len(draft_only)} 개로 NUM_COURSES({NUM_COURSES}) 보다 적습니다."
        )

    random.shuffle(draft_only)
    source_record_ids = draft_only[:NUM_COURSES]

    # source record 의 member_id 가 필요 → 조회
    with conn.cursor() as cur:
        cur.execute(
            "SELECT record_id, member_id FROM records WHERE record_id = ANY(%s)",
            (source_record_ids,),
        )
        member_by_record = {r[0]: r[1] for r in cur.fetchall()}

    course_ids: list[int] = []
    with conn.cursor() as cur:
        for src_record_id in source_record_ids:
            member_id = member_by_record[src_record_id]
            title = random.choice(_COURSE_TITLES)
            difficulty = random.choice(_DIFFICULTIES)
            completion_score = random.randint(50, 100)
            cur.execute(
                _INSERT_COURSE,
                (member_id, src_record_id, title, difficulty, completion_score),
            )
            course_id = cur.fetchone()[0]
            course_ids.append(course_id)
            # source_record 자체도 이 코스의 코스런으로 매핑.
            cur.execute(_UPDATE_RECORD_COURSE_ID, (course_id, src_record_id))

        # 자유러닝 일부를 Course 런으로 전환 (course_id 채움)
        random.shuffle(free)
        promoted = 0
        for cid in course_ids:
            for _ in range(COURSE_RUN_PER_COURSE):
                if not free:
                    break
                rid = free.pop()
                cur.execute(_UPDATE_RECORD_COURSE_ID, (cid, rid))
                promoted += 1

    conn.commit()
    logger.info(
        "courses 적재 완료: %d 개 (source_record + 추가 코스런 %d 건 UPDATE)",
        len(course_ids), promoted,
    )
    return course_ids

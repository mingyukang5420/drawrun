"""course_bookmark 적재.

UNIQUE(member_id, course_id) 제약을 만족시키기 위해 중복 검출 set 사용.
"""

import logging
import random

from loader.config import NUM_BOOKMARKS

logger = logging.getLogger(__name__)

_INSERT_BOOKMARK = """
INSERT INTO course_bookmark (member_id, course_id, created_at, updated_at)
VALUES (%s, %s, NOW(), NOW())
"""


def insert_bookmarks(conn, member_ids: list[int], course_ids: list[int]) -> int:
    random.seed(99)
    seen: set[tuple[int, int]] = set()
    rows: list[tuple[int, int]] = []
    attempts = 0
    # 가능한 조합 수 = member × course. 소형 분포라 보통 여유롭게 채워진다.
    max_attempts = NUM_BOOKMARKS * 20
    while len(rows) < NUM_BOOKMARKS and attempts < max_attempts:
        attempts += 1
        m = random.choice(member_ids)
        c = random.choice(course_ids)
        if (m, c) in seen:
            continue
        seen.add((m, c))
        rows.append((m, c))

    with conn.cursor() as cur:
        cur.executemany(_INSERT_BOOKMARK, rows)
    conn.commit()
    logger.info("course_bookmark 적재 완료: %d 개", len(rows))
    return len(rows)

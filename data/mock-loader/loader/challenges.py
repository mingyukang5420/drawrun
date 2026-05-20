"""챌린지 생성 phase — dev backend /v1/call/test/pipeline 을 N회 호출.

한 호출당 EASY+HARD 한 쌍이 만들어진다 (groupUUID 공유).
응답은 ApiResponse<Void> 라 ID 가 안 오므로, 호출 직후 DB 에서 가장 최근 쌍을 식별한다.

AI 이미지 생성이라 호출당 수십 초 걸릴 수 있어 timeout 을 넉넉히 잡는다.
"""

import logging
import time

from loader.config import NUM_CHALLENGE_PAIRS
from loader.http_client import ApiCallError, create_challenge_pair

logger = logging.getLogger(__name__)

# 호출 사이 기본 대기 — backend 가 직전 AI 호출 마무리 + Redis/디스크 쓰기 정리할 시간.
INTER_CALL_DELAY_SEC = 10
# nginx 504(또는 다른 5xx)가 나면 backend 는 보통 계속 처리 중이므로 더 길게 대기 후 다음 호출.
ERROR_RECOVERY_DELAY_SEC = 75


def generate_challenge_pairs(conn) -> list[dict]:
    """pipeline 을 NUM_CHALLENGE_PAIRS 번 호출하고, 새로 생긴 challenges 를 반환.

    반환: [{id, group_uuid, difficulty, started_at, ended_at, title}]
    호출 후 DB 에서 created_at DESC 로 한 쌍씩 잡아 group_uuid 별로 묶는다.

    nginx 504 등으로 응답이 끊겨도 backend 는 처리를 계속하므로 호출 자체의 실패는
    warning 으로 흘리고 진행한다. 최종적으로 DB SELECT 결과로 검증.
    """
    # 호출 전 기준 시각을 잡아 그 이후에 생긴 챌린지만 식별.
    with conn.cursor() as cur:
        cur.execute("SELECT COALESCE(MAX(created_at), TIMESTAMP 'epoch') FROM challenges")
        baseline = cur.fetchone()[0]
    logger.info("기준 created_at: %s 이후 생긴 챌린지만 추적", baseline)

    for i in range(NUM_CHALLENGE_PAIRS):
        logger.info("챌린지 쌍 생성 %d/%d (AI 호출, 수십 초 소요 가능)",
                    i + 1, NUM_CHALLENGE_PAIRS)
        had_error = False
        try:
            create_challenge_pair()
        except ApiCallError as e:
            had_error = True
            logger.warning(
                "pipeline 호출 실패(backend 는 계속 처리 중일 가능성, 다음 호출까지 %d초 대기): %s",
                ERROR_RECOVERY_DELAY_SEC, e,
            )

        if i < NUM_CHALLENGE_PAIRS - 1:
            time.sleep(ERROR_RECOVERY_DELAY_SEC if had_error else INTER_CALL_DELAY_SEC)

    # 새로 생긴 챌린지를 created_at 순으로 조회.
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT challenge_id, group_uuid, difficulty, started_at, ended_at,
                   created_at, title
            FROM challenges
            WHERE created_at > %s
            ORDER BY created_at ASC
            """,
            (baseline,),
        )
        rows = cur.fetchall()

    expected = NUM_CHALLENGE_PAIRS * 2
    if len(rows) < expected:
        logger.warning(
            "예상 %d 개보다 적은 %d 개 챌린지만 새로 생성됨 — AI 호출 실패 가능성",
            expected, len(rows),
        )

    challenges = [
        {
            "id": r[0],
            "group_uuid": r[1],
            "difficulty": r[2],
            "started_at": r[3],
            "ended_at": r[4],
            "created_at": r[5],
            "title": r[6],
        }
        for r in rows
    ]
    logger.info("새로 생성된 챌린지: %d 개", len(challenges))
    return challenges

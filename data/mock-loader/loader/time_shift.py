"""챌린지 시간 조작 phase.

challenges 의 started_at / ended_at 을 운영 중인 서비스처럼 보이게 UPDATE 한다:
- 가장 늦게 만든 쌍 1개 = 이번 주 진행 중
- 나머지 쌍 = 1·2·3·4·5주 전 (group_uuid 별로 한 묶음씩)

DB 직접 UPDATE — 정상 API 로는 챌린지 시간을 못 바꾼다.
"""

import logging
from collections import OrderedDict
from datetime import datetime, timedelta

from loader.config import CHALLENGE_DURATION_DAYS

logger = logging.getLogger(__name__)

_UPDATE_TIMES = """
UPDATE challenges
SET started_at = %s, ended_at = %s
WHERE challenge_id = ANY(%s)
"""


def shift_challenges_back_in_time(conn, challenges: list[dict]) -> None:
    """group_uuid 별 묶음을 created_at 순서대로 정렬 → 가장 늦은 묶음 = 진행 중,
    그 다음부터 한 주씩 과거로 보낸다.
    """
    # group_uuid 기준 묶기 (입력은 이미 created_at ASC 정렬)
    groups: "OrderedDict[str, list[dict]]" = OrderedDict()
    for c in challenges:
        groups.setdefault(c["group_uuid"], []).append(c)

    group_list = list(groups.values())
    if not group_list:
        logger.warning("시간 조작 대상 챌린지가 없습니다.")
        return

    # 가장 최근에 만든 묶음 = 진행 중 (이번 주 월요일 ~ 일요일).
    now = datetime.now()
    this_monday_midnight = (now - timedelta(days=now.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )

    # group_list[-1] = 진행 중. 거기서부터 역순으로 한 주씩 과거로.
    for idx_from_latest, group in enumerate(reversed(group_list)):
        # idx_from_latest = 0 → 진행 중, 1 → 1주 전, 2 → 2주 전 ...
        started = this_monday_midnight - timedelta(weeks=idx_from_latest)
        ended = started + timedelta(days=CHALLENGE_DURATION_DAYS) - timedelta(seconds=1)
        ids = [c["id"] for c in group]
        with conn.cursor() as cur:
            cur.execute(_UPDATE_TIMES, (started, ended, ids))
        logger.info(
            "group %s (챌린지 %d개) → %s ~ %s",
            group[0]["group_uuid"][:8], len(ids), started, ended,
        )
        # 호출자가 사용 중인 dict 도 새 시간으로 맞춰둔다.
        for c in group:
            c["started_at"] = started
            c["ended_at"] = ended

    conn.commit()
    logger.info("챌린지 시간 조작 완료: %d 쌍", len(group_list))

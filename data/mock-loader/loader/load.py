"""dev 시연용 mockup 적재 진입점.

흐름:
1. signup       — demo01~demo20 회원가입 (이미 있으면 통과)
2. challenges   — TestController pipeline 으로 6쌍(=12개) 챌린지 생성
3. time_shift   — challenges 의 started_at/ended_at 을 운영 중 모양으로 UPDATE
4. drafts       — 각 챌린지마다 N개 CourseDraft 생성 (네이버 정적 지도 PNG 포함)
5. records      — CourseDraft 당 K개 RunningRecord 생성 (similarity_score 자동 계산)
"""

import logging
import sys

from loader.challenges import generate_challenge_pairs
from loader.db import get_connection, wipe_mock_tables
from loader.drafts import create_course_drafts
from loader.http_client import wait_backend_alive
from loader.records import create_records
from loader.signup import signup_demo_members
from loader.time_shift import shift_challenges_back_in_time

logger = logging.getLogger(__name__)


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    try:
        wait_backend_alive()

        conn = get_connection()
        try:
            logger.info("=== Phase 0/5: wipe mock tables (districts/osm_* 보존) ===")
            wipe_mock_tables(conn)

            logger.info("=== Phase 1/5: signup ===")
            members = signup_demo_members()

            logger.info("=== Phase 2/5: challenges (AI 호출, 수십 초/회) ===")
            new_challenges = generate_challenge_pairs(conn)
            if not new_challenges:
                raise RuntimeError("새로 생성된 챌린지가 없음 — AI 호출 결과 확인")

            logger.info("=== Phase 3/5: time_shift ===")
            shift_challenges_back_in_time(conn, new_challenges)

            logger.info("=== Phase 4/5: course drafts ===")
            drafts = create_course_drafts(members, new_challenges, conn)

            logger.info("=== Phase 5/5: running records ===")
            create_records(members, drafts)

            logger.info("=" * 60)
            logger.info("mockup 적재 완료")
            logger.info("=" * 60)
        finally:
            conn.close()
    except Exception:
        logger.exception("mockup 적재 실패")
        sys.exit(1)


if __name__ == "__main__":
    main()

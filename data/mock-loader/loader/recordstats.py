"""member_record_stats 적재.

MemberRecordStatsService.increaseStats 와 같은 형식으로 4개 period_type 을 집계한다:
- DAY:   yyyy-MM-dd
- MONTH: yyyy-MM
- YEAR:  yyyy
- ALL:   "ALL"

INSERT ... SELECT ... GROUP BY 로 records → tracks 조인 후 일괄 적재.
"""

import logging

logger = logging.getLogger(__name__)

# DAY/MONTH/YEAR — period_key 가 컬럼 expression 이라 GROUP BY 에 그대로 사용 가능.
# ALL 은 period_key 가 상수 'ALL' 이라 GROUP BY 에서 빠진다 (PostgreSQL 은 비정수 상수를
# GROUP BY 식으로 받지 않음) → 아래에서 별도 쿼리로 처리.
_PERIOD_SPECS = [
    ("DAY",   "TO_CHAR(r.started_at, 'YYYY-MM-DD')"),
    ("MONTH", "TO_CHAR(r.started_at, 'YYYY-MM')"),
    ("YEAR",  "TO_CHAR(r.started_at, 'YYYY')"),
]


def insert_member_record_stats(conn) -> int:
    total = 0
    with conn.cursor() as cur:
        for period_type, key_expr in _PERIOD_SPECS:
            sql = f"""
                INSERT INTO member_record_stats (
                    member_id, period_type, period_key,
                    total_distance, total_count, total_running_time,
                    created_at, updated_at
                )
                SELECT
                    r.member_id,
                    %s,
                    {key_expr},
                    COALESCE(SUM(t.distance), 0),
                    COUNT(*),
                    COALESCE(SUM(r.running_time), 0),
                    NOW(), NOW()
                FROM records r
                JOIN tracks t ON t.track_id = r.track_id
                GROUP BY r.member_id, {key_expr}
            """
            cur.execute(sql, (period_type,))
            total += cur.rowcount

        cur.execute(
            """
            INSERT INTO member_record_stats (
                member_id, period_type, period_key,
                total_distance, total_count, total_running_time,
                created_at, updated_at
            )
            SELECT
                r.member_id,
                'ALL',
                'ALL',
                COALESCE(SUM(t.distance), 0),
                COUNT(*),
                COALESCE(SUM(r.running_time), 0),
                NOW(), NOW()
            FROM records r
            JOIN tracks t ON t.track_id = r.track_id
            GROUP BY r.member_id
            """
        )
        total += cur.rowcount
    conn.commit()
    logger.info("member_record_stats 적재 완료: %d 행 (DAY/MONTH/YEAR/ALL 합계)", total)
    return total

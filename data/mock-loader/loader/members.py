"""members 적재.

- 비밀번호는 BCrypt 해시 (Spring Security BCryptPasswordEncoder 기본 strength 10 과 호환)
- 모든 회원이 동일 비밀번호 → 단일 해시 생성 후 재사용 (셋업 속도)
- 닉네임은 fixtures/nicknames.json 에서 로드
"""

import json
import logging
from datetime import date
from pathlib import Path

import bcrypt

from loader.config import DEMO_PASSWORD, NUM_MEMBERS

logger = logging.getLogger(__name__)

NICKNAMES_PATH = Path(__file__).resolve().parent.parent / "fixtures" / "nicknames.json"

_INSERT_MEMBER = """
INSERT INTO members (
    login_id, email, password, nickname,
    birth_date, gender, created_at, updated_at
) VALUES (%s, %s, %s, %s, %s, %s, NOW(), NOW())
RETURNING member_id
"""


def insert_members(conn) -> list[int]:
    with open(NICKNAMES_PATH, encoding="utf-8") as f:
        nicknames = json.load(f)
    if len(nicknames) < NUM_MEMBERS:
        raise ValueError(
            f"nicknames.json 에 닉네임이 부족합니다: {len(nicknames)} < {NUM_MEMBERS}"
        )

    hashed = bcrypt.hashpw(DEMO_PASSWORD.encode(), bcrypt.gensalt()).decode()

    member_ids: list[int] = []
    with conn.cursor() as cur:
        for i in range(NUM_MEMBERS):
            login_id = f"demo{i + 1:02d}"
            email = f"{login_id}@example.com"
            nickname = nicknames[i]
            # 1990-01-01 부터 1년 간격
            birth = date(1990 + (i % 25), 1 + (i % 12), 1 + (i % 28))
            gender = "MALE" if i % 2 == 0 else "FEMALE"

            cur.execute(_INSERT_MEMBER, (login_id, email, hashed, nickname, birth, gender))
            member_ids.append(cur.fetchone()[0])
    conn.commit()
    logger.info("members 적재 완료: %d 명 (공통 비밀번호=%s)", len(member_ids), DEMO_PASSWORD)
    return member_ids

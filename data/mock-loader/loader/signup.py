"""회원가입 phase — dev backend /v1/auth/signup 호출.

이미 가입된 loginId 면 SIGNUP_CONFLICT(409) 가 반환되는데, mock 셋업에서는
의도된 재실행이므로 무시하고 계속한다.
"""

import json
import logging
from datetime import date
from pathlib import Path

from loader.config import DEMO_PASSWORD, NUM_MEMBERS
from loader.http_client import ApiCallError, signup

logger = logging.getLogger(__name__)

NICKNAMES_PATH = Path(__file__).resolve().parent.parent / "fixtures" / "nicknames.json"


def _yyyy_mm_dd_dot(d: date) -> str:
    return f"{d.year:04d}.{d.month:02d}.{d.day:02d}"


def signup_demo_members() -> list[dict]:
    """20명을 가입(또는 이미 있으면 통과)시키고, 후속 phase 가 쓸 로그인 정보를 반환.

    반환: [{loginId, password, nickname}]
    """
    with open(NICKNAMES_PATH, encoding="utf-8") as f:
        nicknames = json.load(f)
    if len(nicknames) < NUM_MEMBERS:
        raise ValueError(f"nicknames.json 부족: {len(nicknames)} < {NUM_MEMBERS}")

    created = 0
    skipped = 0
    members: list[dict] = []
    for i in range(NUM_MEMBERS):
        login_id = f"demo{i + 1:02d}"
        nickname = nicknames[i]
        email = f"{login_id}@example.com"
        birth = date(1990 + (i % 25), 1 + (i % 12), 1 + (i % 28))
        gender = "MALE" if i % 2 == 0 else "FEMALE"

        try:
            signup(login_id, email, DEMO_PASSWORD, nickname, _yyyy_mm_dd_dot(birth), gender)
            created += 1
        except ApiCallError as e:
            if e.status == 409 or (isinstance(e.body, dict) and "CONFLICT" in str(e.body)):
                skipped += 1
            else:
                raise
        members.append({"loginId": login_id, "password": DEMO_PASSWORD, "nickname": nickname})

    logger.info("signup 완료: 신규 %d / 기존 %d (총 %d)", created, skipped, len(members))
    return members

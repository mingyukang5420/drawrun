"""CourseDraft 생성 phase — 각 챌린지마다 여러 회원이 그린 코스를 추가.

흐름 (챌린지 1개당 NUM_DRAFTS_PER_CHALLENGE 회 반복):
1. OSM 위 walkable 좌표 시퀀스 추출
2. 네이버 정적 지도 API → 폴리라인 그려진 PNG → base64 data URI
3. POST /v1/editor — backend 가 Track + 디스크 이미지 + CourseDraft 자동 처리
4. 호출한 회원의 draft 목록을 조회해 방금 만든 draft 의 trackImageUrl 회수

반환되는 dict 는 records phase 에서 run/end 호출 시 그대로 사용한다.
"""

import logging
import random

from loader.config import NUM_DRAFTS_PER_CHALLENGE
from loader.http_client import _get, _auth_header, login, save_draft
from loader.map_snapshot import fetch_snapshot_data_uri
from loader.osm_paths import pick_walkable_paths

logger = logging.getLogger(__name__)

# 챌린지 title 을 그대로 prefix 로 활용하고 시연 다양성을 위한 suffix 만 변주.
# 챌린지 title 이 "사자" 면 "사자 따라달리기", "사자 코스" 등으로 생성된다.
_TITLE_SUFFIXES = [
    "따라달리기", "한바퀴", "코스", "도전",
    "트랙", "러닝", "라운드", "챌린지",
]

# course_drafts.title 컬럼이 varchar(20) 이라 안전하게 잘라낸다.
_DRAFT_TITLE_MAX_LEN = 20


def _build_draft_title(challenge_title: str) -> str:
    suffix = random.choice(_TITLE_SUFFIXES)
    raw = f"{challenge_title} {suffix}" if challenge_title else suffix
    return raw[:_DRAFT_TITLE_MAX_LEN]


def _login_all(members: list[dict]) -> dict[str, str]:
    """{loginId: jwt} 캐시."""
    tokens: dict[str, str] = {}
    for m in members:
        tokens[m["loginId"]] = login(m["loginId"], m["password"])
    logger.info("로그인 완료: %d 명", len(tokens))
    return tokens


def _fetch_draft_meta(jwt: str, target_id: int) -> dict:
    """방금 만든 draft 의 trackImageUrl 회수.

    DraftListResponse 에 trackImageUrl 이 들어있다. filter=READY 가장 최근 페이지에서 찾는다.
    """
    body = _get("/v1/editor?filter=READY&page=0", headers=_auth_header(jwt))
    items = (body.get("result") or {}).get("content") or []
    for item in items:
        if item.get("courseDraftId") == target_id:
            return item
    return {}


def create_course_drafts(
    members: list[dict],
    challenges: list[dict],
    osm_conn,
) -> list[dict]:
    """반환: [{courseDraftId, memberLoginId, challengeId, trackImageUrl, coordinates,
              distance_km, started_at_challenge, ended_at_challenge}]"""
    random.seed(7)
    tokens = _login_all(members)

    total_drafts = len(challenges) * NUM_DRAFTS_PER_CHALLENGE
    paths = pick_walkable_paths(osm_conn, total_drafts)

    results: list[dict] = []
    path_iter = iter(paths)
    for ch in challenges:
        for _ in range(NUM_DRAFTS_PER_CHALLENGE):
            coords = next(path_iter)
            member = random.choice(members)
            jwt = tokens[member["loginId"]]
            title = _build_draft_title(ch.get("title") or "")

            png_data_uri = fetch_snapshot_data_uri(coords)
            save_resp = save_draft(
                jwt,
                title=title,
                coordinates=coords,
                thumbnail_base64=png_data_uri,
                challenge_id=ch["id"],
            )
            draft_id = save_resp.get("courseDraftId")
            if draft_id is None:
                raise RuntimeError(f"save_draft 응답에 courseDraftId 없음: {save_resp}")

            meta = _fetch_draft_meta(jwt, draft_id)
            results.append({
                "courseDraftId": draft_id,
                "memberLoginId": member["loginId"],
                "challengeId": ch["id"],
                "trackImageUrl": meta.get("trackImageUrl"),
                "distance_km": meta.get("distance"),
                "coordinates": [{"lat": c["lat"], "lng": c["lng"]} for c in coords],
                "challenge_started_at": ch["started_at"],
                "challenge_ended_at": ch["ended_at"],
            })

    logger.info("CourseDraft 생성 완료: %d 개", len(results))
    return results

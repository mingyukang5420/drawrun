"""Overpass API 클라이언트.

작업지시 4번 쿼리를 호출해 마포구의
- 보행 가능한 way (highway 필터 + foot/access 제외 조건)
- highway=crossing 노드
를 함께 가져온다.
"""

import logging
import time

import requests

logger = logging.getLogger(__name__)

OVERPASS_ENDPOINT = "https://overpass-api.de/api/interpreter"

USER_AGENT = "osm-loader/1.0 (running-app data ingestion)"

QUERY_TEMPLATE = """
[out:json][timeout:300];
area["name"="{district}"]["boundary"="administrative"]->.searchArea;
(
  way["highway"~"^(footway|pedestrian|path|steps|residential|living_street|unclassified|service|primary|secondary|tertiary|primary_link|secondary_link|tertiary_link|cycleway|track)$"]
     ["foot"!="no"]
     ["access"!="private"]
     ["access"!="no"]
     (area.searchArea);
  node["highway"="crossing"](area.searchArea);
);
out tags geom;
"""

BOUNDARY_QUERY_TEMPLATE = """
[out:json][timeout:60];
relation["name"="{district}"]["boundary"="administrative"]["admin_level"~"^[4-6]$"];
out geom;
"""


def fetch_overpass(district: str, timeout: int = 300, max_retries: int = 3) -> dict:
    """Overpass API에 쿼리를 POST. 실패 시 지수 백오프로 재시도.

    파라미터
        district: 행정구역명 (예: "마포구", "강남구")
        timeout: 단일 요청 타임아웃(초). 마포구 규모는 보통 30~60초.
        max_retries: 총 시도 횟수. 마지막 시도까지 실패하면 RuntimeError raise.

    리턴: Overpass JSON 응답 전체 (dict). 'elements' 키에 way/node 배열.

    재시도 정책: 첫 시도 실패 → 1초 대기 → 두 번째 시도 → 2초 대기 → 세 번째 시도.
    마지막 시도 실패 시 sleep 없이 즉시 raise.
    """
    query = QUERY_TEMPLATE.format(district=district)
    last_exc: Exception | None = None
    for attempt in range(1, max_retries + 1):
        try:
            logger.info("Overpass 요청 시도 %d/%d", attempt, max_retries)
            response = requests.post(
                OVERPASS_ENDPOINT,
                data={"data": query},
                headers={"User-Agent": USER_AGENT},
                timeout=timeout,
            )
            response.raise_for_status()
            payload = response.json()
            logger.info(
                "Overpass 응답 수신: elements=%d",
                len(payload.get("elements", [])),
            )
            return payload
        except (requests.RequestException, ValueError) as exc:
            last_exc = exc
            logger.warning("Overpass 요청 실패 (시도 %d): %s", attempt, exc)
            if attempt < max_retries:
                wait = 2 ** (attempt - 1)
                logger.info("재시도 대기 %d초", wait)
                time.sleep(wait)
    raise RuntimeError(f"Overpass 요청 {max_retries}회 모두 실패") from last_exc


def fetch_boundary(district: str, timeout: int = 60, max_retries: int = 3) -> dict:
    """행정구역 경계 relation을 Overpass API에서 조회.

    파라미터
        district: 행정구역명 (예: "마포구", "강남구")
    리턴: Overpass JSON 응답. 'elements[0]'이 relation, members에 outer way geometry 포함.
    """
    query = BOUNDARY_QUERY_TEMPLATE.format(district=district)
    last_exc: Exception | None = None
    for attempt in range(1, max_retries + 1):
        try:
            logger.info("[경계] Overpass 요청 시도 %d/%d (%s)", attempt, max_retries, district)
            response = requests.post(
                OVERPASS_ENDPOINT,
                data={"data": query},
                headers={"User-Agent": USER_AGENT},
                timeout=timeout,
            )
            response.raise_for_status()
            payload = response.json()
            relations = [e for e in payload.get("elements", []) if e.get("type") == "relation"]
            logger.info("[경계] 응답 수신: relations=%d", len(relations))
            return payload
        except (requests.RequestException, ValueError) as exc:
            last_exc = exc
            logger.warning("[경계] 요청 실패 (시도 %d): %s", attempt, exc)
            if attempt < max_retries:
                wait = 2 ** (attempt - 1)
                logger.info("재시도 대기 %d초", wait)
                time.sleep(wait)
    raise RuntimeError(f"[경계] Overpass 요청 {max_retries}회 모두 실패") from last_exc


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    data = fetch_overpass("마포구")
    elements = data.get("elements", [])
    ways = [e for e in elements if e.get("type") == "way"]
    nodes = [e for e in elements if e.get("type") == "node"]
    print(f"total elements: {len(elements)}")
    print(f"  ways: {len(ways)}")
    print(f"  nodes: {len(nodes)}")

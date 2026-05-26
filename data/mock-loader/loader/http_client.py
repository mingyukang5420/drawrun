"""dev backend API 호출 헬퍼.

응답 형식은 ApiResponse<T> = { isSuccess, code, message, result } 로 통일되어 있다.
실패 시 ApiCallError 로 묶어 상위에 던진다 — 호출자가 step 단위로 로그/리트라이 판단.
"""

import logging
import time
from typing import Any

import requests

from loader.config import DEV_API_BASE_URL, TEST_KEY

logger = logging.getLogger(__name__)


class ApiCallError(RuntimeError):
    def __init__(self, msg: str, status: int | None = None, body: Any = None):
        super().__init__(msg)
        self.status = status
        self.body = body


def _post(path: str, *, json: dict | None = None, headers: dict | None = None,
          timeout: int = 30) -> dict:
    url = f"{DEV_API_BASE_URL}{path}"
    h = {"Content-Type": "application/json"}
    if headers:
        h.update(headers)
    resp = requests.post(url, json=json, headers=h, timeout=timeout)
    return _decode(resp, "POST", path)


def _get(path: str, *, headers: dict | None = None, timeout: int = 30) -> dict:
    url = f"{DEV_API_BASE_URL}{path}"
    resp = requests.get(url, headers=headers, timeout=timeout)
    return _decode(resp, "GET", path)


def _decode(resp: requests.Response, method: str, path: str) -> dict:
    try:
        body = resp.json()
    except Exception:
        body = {"raw": resp.text[:200]}
    if resp.status_code >= 400:
        raise ApiCallError(
            f"{method} {path} → {resp.status_code} {body}",
            status=resp.status_code,
            body=body,
        )
    if isinstance(body, dict) and body.get("isSuccess") is False:
        raise ApiCallError(f"{method} {path} → isSuccess=false {body}", body=body)
    return body


# ---------- Auth ----------

def signup(login_id: str, email: str, password: str, nickname: str,
           birth_date_yyyy_mm_dd_dot: str, gender: str) -> None:
    """POST /v1/auth/signup. birthDate 형식은 'yyyy.MM.dd' (JsonFormat 지정)."""
    _post("/v1/auth/signup", json={
        "loginId": login_id,
        "email": email,
        "password": password,
        "nickname": nickname,
        "birthDate": birth_date_yyyy_mm_dd_dot,
        "gender": gender,
    })


def login(login_id: str, password: str) -> str:
    """POST /v1/auth/login → accessToken 반환."""
    body = _post("/v1/auth/login", json={"loginId": login_id, "password": password})
    result = body.get("result") or {}
    token = result.get("accessToken") or result.get("access_token")
    if not token:
        raise ApiCallError(f"login 응답에 accessToken 없음: {body}", body=body)
    return token


def _auth_header(jwt: str) -> dict:
    return {"Authorization": f"Bearer {jwt}"}


# ---------- Challenge (TestController) ----------

def create_challenge_pair() -> None:
    """POST /v1/call/test/pipeline. EASY+HARD 한 쌍 생성. AI 호출이라 응답까지 수십 초 가능."""
    _post(
        "/v1/call/test/pipeline",
        headers={"X-Test-Key": TEST_KEY},
        timeout=180,
    )


# ---------- Editor ----------

def save_draft(jwt: str, *, title: str, coordinates: list[dict],
               thumbnail_base64: str, challenge_id: int) -> dict:
    """POST /v1/editor. SaveResponse(result) 반환."""
    body = _post(
        "/v1/editor",
        json={
            "title": title,
            "coordinates": coordinates,
            "thumbnailBase64": thumbnail_base64,
            "challengeId": challenge_id,
        },
        headers=_auth_header(jwt),
        timeout=60,
    )
    return body.get("result") or {}


def get_walkable_ways(jwt: str, *, min_lat: float, min_lng: float,
                      max_lat: float, max_lng: float, zoom: int = 16) -> dict:
    """GET /v1/editor/way — 영역 내 walkable LineString 좌표 조회."""
    from urllib.parse import urlencode
    qs = urlencode({
        "minLat": min_lat, "minLng": min_lng,
        "maxLat": max_lat, "maxLng": max_lng,
        "zoom": zoom,
    })
    body = _get(f"/v1/editor/way?{qs}", headers=_auth_header(jwt))
    return body.get("result") or {}


# ---------- Run ----------

def create_record(jwt: str, *, course_id: int | None, course_draft_id: int | None,
                  challenge_id: int | None, title: str, distance_km: float,
                  track_image_url: str, running_time_sec: int, avg_pace: float,
                  calories: int, cadence: int, started_at_iso: str,
                  ended_at_iso: str, nodes: list[dict]) -> None:
    """POST /v1/run/end. distance 는 km 단위 (예시 body 3.42 = 3.42km)."""
    _post(
        "/v1/run/end",
        json={
            "courseId": course_id,
            "courseDraftId": course_draft_id,
            "challengeId": challenge_id,
            "title": title,
            "distance": distance_km,
            "trackImageUrl": track_image_url,
            "runningTime": running_time_sec,
            "avgPace": avg_pace,
            "calories": calories,
            "cadence": cadence,
            "startedAt": started_at_iso,
            "endedAt": ended_at_iso,
            "nodes": nodes,
        },
        headers=_auth_header(jwt),
        timeout=60,
    )


# ---------- 유틸 ----------

def wait_backend_alive(max_attempts: int = 10, delay: float = 2.0) -> None:
    """dev backend 가 떠 있는지 한 번 체크. 헬스 endpoint 가 없으면 swagger 로 대체."""
    for i in range(max_attempts):
        try:
            requests.get(f"{DEV_API_BASE_URL}/swagger-ui.html", timeout=5)
            logger.info("dev backend 응답 확인됨")
            return
        except Exception as e:
            logger.info("dev backend 대기 (%d/%d): %s", i + 1, max_attempts, e)
            time.sleep(delay)
    raise ApiCallError("dev backend 응답 없음 — DEV_API_BASE_URL 확인 필요")

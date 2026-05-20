"""트랙/챌린지 이미지 URL placeholder 생성.

application-local.yaml 의 app.upload.* 와 동일한 패턴으로 URL 을 만든다.
실제 파일이 디스크에 없으므로 시연 시 이미지는 404 가 날 수 있다 — 필요하면
같은 UUID 로 파일을 업로드 디렉토리에 올리면 표시된다.

# dev/prod 전환 시
# application.yaml(base) 의 app.upload.* 와 맞추려면 아래 3개 상수만 교체:
#   PUBLIC_BASE_URL       = "https://k14a103.p.ssafy.io"
#   TRACK_PATH_PREFIX     = "/uploads/tracks"
#   CHALLENGE_PATH_PREFIX = "/uploads/challenge"
"""

import uuid

# ----- local 프로파일 기준 -----
PUBLIC_BASE_URL = "http://localhost:8080"
TRACK_PATH_PREFIX = "/api/uploads/tracks"
CHALLENGE_PATH_PREFIX = "/api/uploads/challenge"


def random_track_image_url() -> str:
    return f"{PUBLIC_BASE_URL}{TRACK_PATH_PREFIX}/{uuid.uuid4()}.png"


def random_challenge_image_url() -> str:
    return f"{PUBLIC_BASE_URL}{CHALLENGE_PATH_PREFIX}/{uuid.uuid4()}.png"

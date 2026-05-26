"""OSM 타일 + Pillow 폴리라인 합성으로 트랙 썸네일 PNG 생성.

FE 의 NaverMap takeSnapshot 결과물과 동일한 형식(data:image/png;base64,...)을 만든다.
지도 스타일은 네이버가 아니라 OpenStreetMap. 외부 API 키/과금 없이 무료로 동작.

흐름:
1. 좌표 시퀀스의 bbox 가 출력 이미지(_OUT_W x _OUT_H) 안에 fit 하는 zoom 결정
2. 그 zoom 에서 필요한 OSM 타일 다운로드 + 큰 캔버스에 합성
3. 좌표 → 캔버스 픽셀 변환 → 폴리라인 그리기
4. bbox 중앙을 기준으로 _OUT_W x _OUT_H 영역 크롭
5. PNG 인코딩 → base64
"""

import base64
import io
import logging
import math

import requests
from PIL import Image, ImageDraw

logger = logging.getLogger(__name__)

_TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
_TILE_SIZE = 256
# OSM 타일 사용 정책상 User-Agent 명시 필수 — 안 보내면 차단됨.
_USER_AGENT = "running-mock-loader/1.0 (demo data setup; contact: dev_codelian@naver.com)"

_OUT_W = 600
_OUT_H = 400
_PADDING_PX = 40             # 폴리라인이 이미지 끝에 닿지 않도록 여유
_POLYLINE_COLOR = (0, 128, 255, 255)
_POLYLINE_WIDTH = 5


def _latlng_to_global_pixel(lat: float, lng: float, zoom: int) -> tuple[float, float]:
    """Web Mercator 전역 픽셀 좌표 (zoom 기준)."""
    n = (2 ** zoom) * _TILE_SIZE
    x = (lng + 180.0) / 360.0 * n
    lat_rad = math.radians(lat)
    y = (1.0 - math.log(math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi) / 2.0 * n
    return x, y


def _choose_zoom(min_lat: float, min_lng: float, max_lat: float, max_lng: float) -> int:
    """bbox 가 (_OUT_W - padding × 2) x (_OUT_H - padding × 2) 안에 들어가는 최대 zoom."""
    fit_w = _OUT_W - _PADDING_PX * 2
    fit_h = _OUT_H - _PADDING_PX * 2
    for zoom in range(18, 8, -1):
        x1, y1 = _latlng_to_global_pixel(min_lat, min_lng, zoom)
        x2, y2 = _latlng_to_global_pixel(max_lat, max_lng, zoom)
        if abs(x2 - x1) <= fit_w and abs(y2 - y1) <= fit_h:
            return zoom
    return 9


def _fetch_tile(session: requests.Session, zoom: int, x: int, y: int) -> Image.Image:
    resp = session.get(
        _TILE_URL.format(z=zoom, x=x, y=y),
        timeout=15,
        headers={"User-Agent": _USER_AGENT},
    )
    resp.raise_for_status()
    return Image.open(io.BytesIO(resp.content)).convert("RGBA")


def fetch_snapshot_png(nodes) -> bytes:
    """좌표 리스트 [{lat, lng}, ...] → 폴리라인이 그려진 PNG 바이너리."""
    points = [(float(n["lat"]), float(n["lng"])) for n in nodes]
    if len(points) < 2:
        raise ValueError("폴리라인을 그리려면 좌표가 2개 이상 필요합니다.")

    lats = [p[0] for p in points]
    lngs = [p[1] for p in points]
    min_lat, max_lat = min(lats), max(lats)
    min_lng, max_lng = min(lngs), max(lngs)

    zoom = _choose_zoom(min_lat, min_lng, max_lat, max_lng)

    # 좌표를 전역 픽셀로.
    px_pts = [_latlng_to_global_pixel(lat, lng, zoom) for lat, lng in points]
    px_xs = [p[0] for p in px_pts]
    px_ys = [p[1] for p in px_pts]
    center_x = (min(px_xs) + max(px_xs)) / 2.0
    center_y = (min(px_ys) + max(px_ys)) / 2.0

    # 최종 크롭할 영역 (전역 픽셀).
    out_left = center_x - _OUT_W / 2.0
    out_top = center_y - _OUT_H / 2.0
    out_right = out_left + _OUT_W
    out_bottom = out_top + _OUT_H

    # 필요한 타일 인덱스 범위.
    tile_x0 = int(math.floor(out_left / _TILE_SIZE))
    tile_y0 = int(math.floor(out_top / _TILE_SIZE))
    tile_x1 = int(math.floor((out_right - 1) / _TILE_SIZE))
    tile_y1 = int(math.floor((out_bottom - 1) / _TILE_SIZE))

    canvas_w = (tile_x1 - tile_x0 + 1) * _TILE_SIZE
    canvas_h = (tile_y1 - tile_y0 + 1) * _TILE_SIZE
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (240, 240, 240, 255))

    sess = requests.Session()
    for tx in range(tile_x0, tile_x1 + 1):
        for ty in range(tile_y0, tile_y1 + 1):
            try:
                tile = _fetch_tile(sess, zoom, tx, ty)
                canvas.paste(tile, ((tx - tile_x0) * _TILE_SIZE, (ty - tile_y0) * _TILE_SIZE))
            except Exception as e:
                # 한 장 실패해도 회색 배경으로 채워진 채 진행 — 시연 흐름 중단 방지.
                logger.warning("OSM tile %d/%d/%d 다운로드 실패: %s", zoom, tx, ty, e)

    # 캔버스 픽셀 좌표로 변환해서 폴리라인.
    origin_x = tile_x0 * _TILE_SIZE
    origin_y = tile_y0 * _TILE_SIZE
    line_pts = [(x - origin_x, y - origin_y) for x, y in px_pts]

    draw = ImageDraw.Draw(canvas)
    draw.line(line_pts, fill=_POLYLINE_COLOR, width=_POLYLINE_WIDTH, joint="curve")

    # 최종 _OUT_W x _OUT_H 로 크롭.
    crop_left = int(round(out_left - origin_x))
    crop_top = int(round(out_top - origin_y))
    final = canvas.crop((crop_left, crop_top, crop_left + _OUT_W, crop_top + _OUT_H))
    final = final.convert("RGB")

    buf = io.BytesIO()
    final.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def fetch_snapshot_data_uri(nodes) -> str:
    """EditorController.save 가 받는 'data:image/png;base64,...' 형식으로 반환."""
    png = fetch_snapshot_png(nodes)
    b64 = base64.b64encode(png).decode("ascii")
    return f"data:image/png;base64,{b64}"

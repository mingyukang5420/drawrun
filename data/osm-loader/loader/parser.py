"""Overpass JSON 응답을 DB INSERT용 dict로 변환한다.

좌표 순서 주의:
    Overpass: {"lat": y, "lon": x}
    PostGIS WKT: "POINT(x y)" / "LINESTRING(x y, x y, ...)"  → lon lat 순
"""
import logging

logger = logging.getLogger(__name__)


def parse_way(element: dict) -> dict | None:
    """way element를 osm_ways INSERT용 dict로 변환.

    geometry 좌표가 2개 미만이면 None 반환 (LINESTRING 불가).
    """
    geometry = element.get("geometry") or []
    if len(geometry) < 2:
        return None

    tags = element.get("tags", {})

    # PostGIS WKT는 lon lat 순
    coords = ", ".join(f"{p['lon']} {p['lat']}" for p in geometry)
    geom_wkt = f"LINESTRING({coords})"

    # layer는 정수. OSM 태그가 "1.5" 같은 비정수일 가능성 있어 변환 실패 시 0.
    try:
        layer = int(tags.get("layer", 0))
    except (ValueError, TypeError):
        layer = 0

    # lit는 3-state: None(정보 없음) / True(yes) / False(yes 외 명시값)
    lit_raw = tags.get("lit")
    lit = (lit_raw == "yes") if lit_raw is not None else None

    return {
        "osm_id": element["id"],
        "highway": tags["highway"],
        "name": tags.get("name"),
        "geom_wkt": geom_wkt,
        "foot": tags.get("foot"),
        "access": tags.get("access"),
        "oneway": tags.get("oneway"),
        "bridge": tags.get("bridge") == "yes",
        "tunnel": tags.get("tunnel") == "yes",
        "indoor": tags.get("indoor") == "yes",
        "layer": layer,
        "surface": tags.get("surface"),
        "lit": lit,
        "sidewalk": tags.get("sidewalk"),
    }


def parse_node(element: dict) -> dict:
    """crossing node element를 osm_crossings INSERT용 dict로 변환."""
    tags = element.get("tags", {})
    geom_wkt = f"POINT({element['lon']} {element['lat']})"
    return {
        "osm_id": element["id"],
        "crossing": tags.get("crossing"),
        "has_signals": tags.get("traffic_signals") == "yes",
        "geom_wkt": geom_wkt,
    }


def _assemble_ring(segments: list[list[tuple[float, float]]]) -> list[tuple[float, float]] | None:
    """outer 세그먼트 리스트를 head-to-tail로 연결해 닫힌 링을 반환.

    각 세그먼트는 (lon, lat) 튜플의 리스트.
    끝점 매칭은 1e-6 허용 오차를 적용한다.
    연결에 실패하면 None 반환.
    """
    EPS = 1e-6

    def near(a: tuple, b: tuple) -> bool:
        return abs(a[0] - b[0]) < EPS and abs(a[1] - b[1]) < EPS

    if not segments:
        return None

    ring = list(segments[0])
    remaining = list(segments[1:])

    while remaining:
        last = ring[-1]
        matched = False
        for i, seg in enumerate(remaining):
            if near(seg[0], last):
                ring.extend(seg[1:])
                remaining.pop(i)
                matched = True
                break
            if near(seg[-1], last):
                ring.extend(reversed(seg[:-1]))
                remaining.pop(i)
                matched = True
                break
        if not matched:
            logger.warning("세그먼트 연결 실패: 남은 세그먼트 %d개", len(remaining))
            return None

    if not near(ring[0], ring[-1]):
        ring.append(ring[0])

    return ring


def parse_boundary(
    element: dict,
    sido: str,
    gu: str,
    district_code: str,
    center_lon: float,
    center_lat: float,
) -> dict | None:
    """Overpass boundary relation element를 district INSERT용 dict로 변환.

    outer role 멤버의 geometry를 연결해 POLYGON WKT를 생성한다.
    center_point는 기상청 격자 위경도 파일 좌표를 그대로 사용한다.
    조립 실패 시 None 반환.
    """
    members = element.get("members") or []
    segments: list[list[tuple[float, float]]] = []
    for m in members:
        if m.get("role") != "outer":
            continue
        geometry = m.get("geometry") or []
        if len(geometry) < 2:
            continue
        segments.append([(p["lon"], p["lat"]) for p in geometry])

    if not segments:
        logger.warning("[%s] outer 세그먼트 없음", gu)
        return None

    ring = _assemble_ring(segments)
    if ring is None:
        logger.warning("[%s] polygon 링 조립 실패", gu)
        return None

    coords = ", ".join(f"{lon} {lat}" for lon, lat in ring)
    boundary_wkt = f"POLYGON(({coords}))"
    center_wkt = f"POINT({center_lon} {center_lat})"

    logger.info("[%s] boundary 조립 완료: %d points", gu, len(ring))
    return {
        "district_code": district_code,
        "sido": sido,
        "gu": gu,
        "center_wkt": center_wkt,
        "boundary_wkt": boundary_wkt,
    }


def parse_response(data: dict) -> tuple[list[dict], list[dict]]:
    """Overpass 응답에서 way/crossing을 분리해 두 리스트로 반환.

    way 중 geometry 좌표가 부족(< 2점)한 항목은 제거하고 건수를 로그.
    """
    elements = data.get("elements", [])
    ways: list[dict] = []
    crossings: list[dict] = []
    skipped_ways = 0

    for element in elements:
        kind = element.get("type")
        if kind == "way":
            parsed = parse_way(element)
            if parsed is None:
                skipped_ways += 1
                continue
            ways.append(parsed)
        elif kind == "node":
            crossings.append(parse_node(element))

    if skipped_ways:
        logger.info("geometry 부족 way 제거: %d건", skipped_ways)
    logger.info("파싱 완료: ways=%d, crossings=%d", len(ways), len(crossings))

    return ways, crossings

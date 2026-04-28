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

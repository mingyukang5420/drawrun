"""OSM 데이터 수집 및 CSV 저장.

Overpass API + Open Elevation API를 호출하여
osm_ways.csv, osm_crossings.csv를 생성한다.

0.0으로 대체된 고도값은 재요청하여 CSV에 반영한다.
(한강변 등 실제 0m 지점은 0.0 유지)

실행 후 생성된 CSV 파일을 Google Drive에 업로드하여 팀원과 공유한다.
이 스크립트는 최초 1회 또는 데이터 갱신 시에만 실행한다.

실행: python -m loader.fetch
출력: data/osm_ways.csv, data/osm_crossings.csv
"""

import csv
import json
import logging
import os
import time

from loader.elevation_client import (
    BATCH_SIZE,
    attach_elevation,
    calc_elevation_stats,
    fetch_elevation_batch,
)
from loader.overpass_client import fetch_boundary, fetch_overpass
from loader.parser import parse_boundary, parse_response

logger = logging.getLogger(__name__)

ROUTE_DISTRICTS = [
    {"sido": "서울특별시", "gu": "마포구", "code": "11440",
     "center_lon": 126.910530555555, "center_lat": 37.5607055555555},
    {"sido": "서울특별시", "gu": "강남구", "code": "11680",
     "center_lon": 127.049555555555, "center_lat": 37.514575},
]

BOUNDARY_ONLY_DISTRICTS = [
    {"sido": "서울특별시", "gu": "종로구",   "code": "11110", "center_lon": 126.977369, "center_lat": 37.593220},
    {"sido": "서울특별시", "gu": "중구",     "code": "11140", "center_lon": 126.997841, "center_lat": 37.563732},
    {"sido": "서울특별시", "gu": "용산구",   "code": "11170", "center_lon": 126.990013, "center_lat": 37.532701},
    {"sido": "서울특별시", "gu": "성동구",   "code": "11200", "center_lon": 127.036956, "center_lat": 37.563429},
    {"sido": "서울특별시", "gu": "광진구",   "code": "11215", "center_lon": 127.082186, "center_lat": 37.538614},
    {"sido": "서울특별시", "gu": "동대문구", "code": "11230", "center_lon": 127.040357, "center_lat": 37.574391},
    {"sido": "서울특별시", "gu": "중랑구",   "code": "11260", "center_lon": 127.094357, "center_lat": 37.606314},
    {"sido": "서울특별시", "gu": "성북구",   "code": "11290", "center_lon": 127.016788, "center_lat": 37.589528},
    {"sido": "서울특별시", "gu": "강북구",   "code": "11305", "center_lon": 127.028523, "center_lat": 37.639710},
    {"sido": "서울특별시", "gu": "도봉구",   "code": "11320", "center_lon": 127.047226, "center_lat": 37.668701},
    {"sido": "서울특별시", "gu": "노원구",   "code": "11350", "center_lon": 127.076538, "center_lat": 37.654164},
    {"sido": "서울특별시", "gu": "은평구",   "code": "11380", "center_lon": 126.927580, "center_lat": 37.602741},
    {"sido": "서울특별시", "gu": "서대문구", "code": "11410", "center_lon": 126.938378, "center_lat": 37.579427},
    {"sido": "서울특별시", "gu": "양천구",   "code": "11470", "center_lon": 126.866940, "center_lat": 37.516921},
    {"sido": "서울특별시", "gu": "강서구",   "code": "11500", "center_lon": 126.849761, "center_lat": 37.550987},
    {"sido": "서울특별시", "gu": "구로구",   "code": "11530", "center_lon": 126.887422, "center_lat": 37.495449},
    {"sido": "서울특별시", "gu": "금천구",   "code": "11545", "center_lon": 126.895782, "center_lat": 37.456893},
    {"sido": "서울특별시", "gu": "영등포구", "code": "11560", "center_lon": 126.896560, "center_lat": 37.526447},
    {"sido": "서울특별시", "gu": "동작구",   "code": "11590", "center_lon": 126.939760, "center_lat": 37.512409},
    {"sido": "서울특별시", "gu": "관악구",   "code": "11620", "center_lon": 126.951401, "center_lat": 37.478518},
    {"sido": "서울특별시", "gu": "서초구",   "code": "11650", "center_lon": 127.032710, "center_lat": 37.483617},
    {"sido": "서울특별시", "gu": "송파구",   "code": "11710", "center_lon": 127.112245, "center_lat": 37.514535},
    {"sido": "서울특별시", "gu": "강동구",   "code": "11740", "center_lon": 127.149713, "center_lat": 37.552994},
]

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
WAYS_CSV = os.path.join(DATA_DIR, "osm_ways.csv")
CROSSINGS_CSV = os.path.join(DATA_DIR, "osm_crossings.csv")
DISTRICTS_CSV = os.path.join(DATA_DIR, "districts.csv")

DISTRICTS_FIELDS = ["district_id", "sido", "gu", "center_wkt", "boundary_wkt"]

WAYS_FIELDS = [
    "osm_id",
    "highway",
    "name",
    "geom_wkt",
    "foot",
    "access",
    "oneway",
    "bridge",
    "tunnel",
    "indoor",
    "layer",
    "surface",
    "lit",
    "sidewalk",
    "elevation_nodes",
    "elevation_gain",
    "avg_uphill_grade",
]
CROSSINGS_FIELDS = ["osm_id", "crossing", "has_signals", "geom_wkt"]


def refill_ways(ways: list[dict]) -> list[dict]:
    """0.0 노드만 재요청하여 ways 리스트에 반영. CSV 저장 전 호출."""
    zero_coords: dict[tuple, None] = {}
    for w in ways:
        for n in w.get("elevation_nodes", []):
            if n["elev"] == 0.0:
                key = (round(n["lat"], 7), round(n["lng"], 7))
                zero_coords[key] = None

    if not zero_coords:
        logger.info("0.0 노드 없음. refill 스킵.")
        return ways

    coord_list = [{"lat": k[0], "lng": k[1]} for k in zero_coords]
    logger.info("0.0 노드 재요청: %d개 (중복 제거)", len(coord_list))

    elev_map: dict[tuple, float] = {}
    for i in range(0, len(coord_list), BATCH_SIZE):
        batch = coord_list[i : i + BATCH_SIZE]
        elevs = fetch_elevation_batch(batch)
        for coord, elev in zip(batch, elevs):
            elev_map[(round(coord["lat"], 7), round(coord["lng"], 7))] = elev
        success = sum(1 for e in elevs if e != 0.0)
        logger.info(
            "refill %d/%d — 성공: %d, 여전히 0.0: %d",
            min(i + BATCH_SIZE, len(coord_list)),
            len(coord_list),
            success,
            len(elevs) - success,
        )
        time.sleep(0.3)

    refilled = []
    for w in ways:
        new_nodes = []
        changed = False
        for n in w.get("elevation_nodes", []):
            if n["elev"] == 0.0:
                key = (round(n["lat"], 7), round(n["lng"], 7))
                new_elev = elev_map.get(key, 0.0)
                if new_elev != 0.0:
                    changed = True
                new_nodes.append({**n, "elev": new_elev})
            else:
                new_nodes.append(n)

        if changed:
            gain, avg_grade = calc_elevation_stats(new_nodes)
            refilled.append(
                {
                    **w,
                    "elevation_nodes": new_nodes,
                    "elevation_gain": gain,
                    "avg_uphill_grade": avg_grade,
                }
            )
        else:
            refilled.append(w)

    return refilled


def save_csv(
    all_ways: list[dict],
    all_crossings: list[dict],
    all_districts: list[dict],
) -> None:
    with open(WAYS_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=WAYS_FIELDS)
        writer.writeheader()
        for w in all_ways:
            writer.writerow(
                {
                    **{k: w.get(k) for k in WAYS_FIELDS if k != "elevation_nodes"},
                    "elevation_nodes": json.dumps(
                        w.get("elevation_nodes", []), ensure_ascii=False
                    ),
                }
            )

    with open(CROSSINGS_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CROSSINGS_FIELDS)
        writer.writeheader()
        for c in all_crossings:
            writer.writerow({k: c.get(k) for k in CROSSINGS_FIELDS})

    with open(DISTRICTS_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=DISTRICTS_FIELDS)
        writer.writeheader()
        for d in all_districts:
            writer.writerow({k: d.get(k) for k in DISTRICTS_FIELDS})


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    os.makedirs(DATA_DIR, exist_ok=True)

    all_ways: list[dict] = []
    all_crossings: list[dict] = []
    all_districts: list[dict] = []

    # 1. 도로 데이터 구: Overpass ways/crossings + 고도 API + boundary
    for d in ROUTE_DISTRICTS:
        gu = d["gu"]
        logger.info("=" * 50)
        logger.info("[%s] 수집 시작 (도로+경계)", gu)
        logger.info("=" * 50)

        data = fetch_overpass(gu)
        ways, crossings = parse_response(data)

        logger.info("[%s] 고도값 부착 중...", gu)
        ways = attach_elevation(ways)

        all_ways.extend(ways)
        all_crossings.extend(crossings)
        logger.info("[%s] 수집 완료: ways=%d, crossings=%d", gu, len(ways), len(crossings))

        boundary_data = fetch_boundary(gu)
        relations = [e for e in boundary_data.get("elements", []) if e.get("type") == "relation"]
        if relations:
            district_dict = parse_boundary(
                relations[0],
                sido=d["sido"],
                gu=gu,
                district_id=d["code"],
                center_lon=d["center_lon"],
                center_lat=d["center_lat"],
            )
            if district_dict:
                all_districts.append(district_dict)
        else:
            logger.warning("[%s] boundary relation 없음", gu)

    # 2. 경계 전용 구: boundary만 수집 (ways/crossings/elevation 생략)
    for d in BOUNDARY_ONLY_DISTRICTS:
        gu = d["gu"]
        logger.info("[%s] boundary 수집 중...", gu)
        boundary_data = fetch_boundary(gu)
        relations = [e for e in boundary_data.get("elements", []) if e.get("type") == "relation"]
        if relations:
            district_dict = parse_boundary(
                relations[0],
                sido=d["sido"],
                gu=gu,
                district_id=d["code"],
                center_lon=d["center_lon"],
                center_lat=d["center_lat"],
            )
            if district_dict:
                all_districts.append(district_dict)
        else:
            logger.warning("[%s] boundary relation 없음", gu)

    # 2. 0.0 노드 재요청 → CSV에 반영
    logger.info("0.0 고도값 재요청 중...")
    all_ways = refill_ways(all_ways)

    # 3. CSV 저장
    save_csv(all_ways, all_crossings, all_districts)
    logger.info("CSV 저장 완료")
    logger.info("  osm_ways.csv:      %d rows → %s", len(all_ways), WAYS_CSV)
    logger.info("  osm_crossings.csv: %d rows → %s", len(all_crossings), CROSSINGS_CSV)
    logger.info("  districts.csv:     %d rows → %s", len(all_districts), DISTRICTS_CSV)
    logger.info("districts.csv만 Google Drive에 업로드 후 GDRIVE_DISTRICTS_URL을 갱신하세요.")


if __name__ == "__main__":
    main()

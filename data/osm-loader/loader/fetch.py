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
from loader.overpass_client import fetch_overpass
from loader.parser import parse_response

logger = logging.getLogger(__name__)

DISTRICTS = [
    "마포구",
    "강남구",
]

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
WAYS_CSV = os.path.join(DATA_DIR, "osm_ways.csv")
CROSSINGS_CSV = os.path.join(DATA_DIR, "osm_crossings.csv")

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


def save_csv(all_ways: list[dict], all_crossings: list[dict]) -> None:
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


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    os.makedirs(DATA_DIR, exist_ok=True)

    all_ways: list[dict] = []
    all_crossings: list[dict] = []

    # 1. Overpass + 고도 API
    for district in DISTRICTS:
        logger.info("=" * 50)
        logger.info("[%s] 수집 시작", district)
        logger.info("=" * 50)

        data = fetch_overpass(district)
        ways, crossings = parse_response(data)

        logger.info("[%s] 고도값 부착 중...", district)
        ways = attach_elevation(ways)

        all_ways.extend(ways)
        all_crossings.extend(crossings)
        logger.info(
            "[%s] 수집 완료: ways=%d, crossings=%d", district, len(ways), len(crossings)
        )

    # 2. 0.0 노드 재요청 → CSV에 반영
    logger.info("0.0 고도값 재요청 중...")
    all_ways = refill_ways(all_ways)

    # 3. CSV 저장
    save_csv(all_ways, all_crossings)
    logger.info("CSV 저장 완료")
    logger.info("  osm_ways.csv:      %d rows → %s", len(all_ways), WAYS_CSV)
    logger.info("  osm_crossings.csv: %d rows → %s", len(all_crossings), CROSSINGS_CSV)
    logger.info("Google Drive에 업로드 후 팀원에게 공유하세요.")


if __name__ == "__main__":
    main()

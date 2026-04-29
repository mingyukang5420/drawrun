"""OSM 데이터 수집 및 CSV 저장.

Overpass API + Open Elevation API를 호출하여
osm_ways.csv, osm_crossings.csv를 생성한다.

실행 후 생성된 CSV 파일을 Google Drive에 업로드하여 팀원과 공유한다.
이 스크립트는 최초 1회 또는 데이터 갱신 시에만 실행한다.

실행: python -m loader.fetch
출력: data/osm_ways.csv, data/osm_crossings.csv
"""

import csv
import json
import logging
import os

from loader.elevation_client import attach_elevation
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


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    os.makedirs(DATA_DIR, exist_ok=True)

    all_ways: list[dict] = []
    all_crossings: list[dict] = []

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

    # CSV 저장
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

    logger.info("CSV 저장 완료")
    logger.info("  osm_ways.csv:      %d rows → %s", len(all_ways), WAYS_CSV)
    logger.info("  osm_crossings.csv: %d rows → %s", len(all_crossings), CROSSINGS_CSV)
    logger.info("Google Drive에 업로드 후 팀원에게 공유하세요.")


if __name__ == "__main__":
    main()

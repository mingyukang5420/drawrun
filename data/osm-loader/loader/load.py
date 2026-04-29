"""CSV → DB 적재.

Google Drive에서 osm_ways.csv, osm_crossings.csv를 다운로드하여
DB에 적재한다.

팀원 초기 세팅, 서버 배포, Docker volume 초기화 시 모두 이 스크립트를 실행한다.
API 호출 없이 CSV에서 바로 적재하므로 빠르게 완료된다.

Google Drive 공유 링크 설정:
    .env에 아래 두 항목을 추가한다.
    GDRIVE_WAYS_URL=https://drive.google.com/uc?id={file_id}
    GDRIVE_CROSSINGS_URL=https://drive.google.com/uc?id={file_id}

실행: python -m loader.load
"""

import csv
import io
import json
import logging
import os

import psycopg2
import requests
from dotenv import load_dotenv
from pathlib import Path

from loader.config import load_db_config
from loader.db import get_connection, insert_ways_batch, insert_crossings_batch

logger = logging.getLogger(__name__)

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")


def _load_gdrive_urls() -> tuple[str, str]:
    """환경변수에서 Google Drive URL 로드."""
    project_root = Path(__file__).resolve().parent.parent
    load_dotenv(project_root / ".env")

    ways_url = os.environ.get("GDRIVE_WAYS_URL")
    crossings_url = os.environ.get("GDRIVE_CROSSINGS_URL")

    if not ways_url or not crossings_url:
        raise KeyError(".env에 GDRIVE_WAYS_URL, GDRIVE_CROSSINGS_URL을 설정해주세요.")
    return ways_url, crossings_url


def _download_csv(url: str, label: str) -> list[dict]:
    """Google Drive URL에서 CSV 다운로드 후 dict 리스트 반환."""
    logger.info("[%s] 다운로드 중: %s", label, url)
    resp = requests.get(url, timeout=60)
    resp.raise_for_status()
    reader = csv.DictReader(io.StringIO(resp.content.decode("utf-8")))
    rows = list(reader)
    logger.info("[%s] 다운로드 완료: %d rows", label, len(rows))
    return rows


def _parse_ways(rows: list[dict]) -> list[dict]:
    """CSV row → insert_ways_batch 입력 형식 변환."""
    ways = []
    for r in rows:
        ways.append(
            {
                "osm_id": int(r["osm_id"]),
                "highway": r["highway"],
                "name": r["name"] or None,
                "geom_wkt": r["geom_wkt"],
                "foot": r["foot"] or None,
                "access": r["access"] or None,
                "oneway": r["oneway"] or None,
                "bridge": r["bridge"] == "True",
                "tunnel": r["tunnel"] == "True",
                "indoor": r["indoor"] == "True",
                "layer": int(r["layer"] or 0),
                "surface": r["surface"] or None,
                "lit": None if r["lit"] == "" else r["lit"] == "True",
                "sidewalk": r["sidewalk"] or None,
                "elevation_nodes": json.loads(r["elevation_nodes"] or "[]"),
                "elevation_gain": float(r["elevation_gain"] or 0.0),
                "avg_uphill_grade": float(r["avg_uphill_grade"] or 0.0),
            }
        )
    return ways


def _parse_crossings(rows: list[dict]) -> list[dict]:
    """CSV row → insert_crossings_batch 입력 형식 변환."""
    return [
        {
            "osm_id": int(r["osm_id"]),
            "crossing": r["crossing"] or None,
            "has_signals": r["has_signals"] == "True",
            "geom_wkt": r["geom_wkt"],
        }
        for r in rows
    ]


def _count(conn, table: str) -> int:
    with conn.cursor() as cur:
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        return cur.fetchone()[0]


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    ways_url, crossings_url = _load_gdrive_urls()

    # CSV 다운로드
    ways_rows = _download_csv(ways_url, "osm_ways")
    crossings_rows = _download_csv(crossings_url, "osm_crossings")

    # 형식 변환
    ways = _parse_ways(ways_rows)
    crossings = _parse_crossings(crossings_rows)

    # DB 적재
    cfg = load_db_config()
    logger.info("DB 연결 (host=%s db=%s)", cfg["host"], cfg["dbname"])
    conn = get_connection(cfg)

    try:
        logger.info("osm_ways INSERT 시작 (대상=%d)", len(ways))
        insert_ways_batch(conn, ways)

        logger.info("osm_crossings INSERT 시작 (대상=%d)", len(crossings))
        insert_crossings_batch(conn, crossings)

        logger.info(
            "적재 완료: osm_ways=%d, osm_crossings=%d",
            _count(conn, "osm_ways"),
            _count(conn, "osm_crossings"),
        )
    finally:
        conn.close()


if __name__ == "__main__":
    main()

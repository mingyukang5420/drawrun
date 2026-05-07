"""CSV → DB 적재.

data/ 폴더의 로컬 CSV를 우선 사용하고, 없으면 Google Drive에서 다운로드한다.
팀원 초기 세팅, 서버 배포, Docker volume 초기화 시 모두 이 스크립트를 실행한다.

로컬 CSV 사용 (fetch.py 실행 후):
    python -m loader.load

Google Drive 사용 (.env 설정 필요):
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
from loader.db import get_connection, insert_ways_batch, insert_crossings_batch, upsert_districts

logger = logging.getLogger(__name__)

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
DISTRICTS_CSV_NAME = "districts.csv"


def _load_gdrive_urls() -> tuple[str, str, str]:
    """환경변수에서 Google Drive URL 로드."""
    project_root = Path(__file__).resolve().parent.parent
    load_dotenv(project_root / ".env")

    ways_url = os.environ.get("GDRIVE_WAYS_URL")
    crossings_url = os.environ.get("GDRIVE_CROSSINGS_URL")
    districts_url = os.environ.get("GDRIVE_DISTRICTS_URL")

    if not ways_url or not crossings_url or not districts_url:
        raise KeyError(".env에 GDRIVE_WAYS_URL, GDRIVE_CROSSINGS_URL, GDRIVE_DISTRICTS_URL을 설정해주세요.")
    return ways_url, crossings_url, districts_url


def _read_local_csv(path: str, label: str) -> list[dict]:
    """로컬 CSV 파일 읽기."""
    logger.info("[%s] 로컬 파일 사용: %s", label, path)
    with open(path, encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    logger.info("[%s] 읽기 완료: %d rows", label, len(rows))
    return rows


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


def _parse_districts(rows: list[dict]) -> list[dict]:
    """CSV row → upsert_districts 입력 형식 변환."""
    return [
        {
            "district_id": r["district_id"],
            "sido": r["sido"],
            "gu": r["gu"],
            "center_wkt": r["center_wkt"],
            "boundary_wkt": r["boundary_wkt"],
        }
        for r in rows
    ]


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
    

def split_ways(conn) -> None:
    """osm_ways를 교차점 기준으로 쪼개어 osm_ways_split에 적재."""
    with conn.cursor() as cur:
        logger.info("osm_ways_split 초기화...")
        cur.execute("""
            INSERT INTO osm_ways_split (source_osm_id, geom)
            SELECT
                A.osm_id,
                (ST_Dump(
                    ST_Split(
                        A.geom,
                        ST_CollectionExtract(ST_Union(ST_Intersection(A.geom, B.geom)), 1)
                    )
                )).geom
            FROM osm_ways A
            JOIN osm_ways B ON ST_Intersects(A.geom, B.geom) AND A.osm_id != B.osm_id
            GROUP BY A.osm_id, A.geom
        """)
        conn.commit()
    logger.info("osm_ways_split 적재 완료: %d rows", _count(conn, "osm_ways_split"))


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    # 로컬 CSV 우선, 없으면 Google Drive
    ways_local = os.path.join(DATA_DIR, "osm_ways.csv")
    crossings_local = os.path.join(DATA_DIR, "osm_crossings.csv")
    districts_local = os.path.join(DATA_DIR, DISTRICTS_CSV_NAME)

    if (os.path.exists(ways_local)
            and os.path.exists(crossings_local)
            and os.path.exists(districts_local)):
        ways_rows = _read_local_csv(ways_local, "osm_ways")
        crossings_rows = _read_local_csv(crossings_local, "osm_crossings")
        districts_rows = _read_local_csv(districts_local, "districts")
    else:
        ways_url, crossings_url, districts_url = _load_gdrive_urls()
        ways_rows = _download_csv(ways_url, "osm_ways")
        crossings_rows = _download_csv(crossings_url, "osm_crossings")
        districts_rows = _download_csv(districts_url, "districts")

    # 형식 변환
    ways = _parse_ways(ways_rows)
    crossings = _parse_crossings(crossings_rows)
    districts = _parse_districts(districts_rows)

    # DB 적재
    cfg = load_db_config()
    logger.info("DB 연결 (host=%s db=%s)", cfg["host"], cfg["dbname"])
    conn = get_connection(cfg)

    try:
        logger.info("district UPSERT 시작 (대상=%d)", len(districts))
        upsert_districts(conn, districts)
        logger.info("적재 완료: district=%d", _count(conn, "districts"))

        logger.info("osm_ways INSERT 시작 (대상=%d)", len(ways))
        insert_ways_batch(conn, ways)

        logger.info("osm_crossings INSERT 시작 (대상=%d)", len(crossings))
        insert_crossings_batch(conn, crossings)

        logger.info(
            "적재 완료: osm_ways=%d, osm_crossings=%d",
            _count(conn, "osm_ways"),
            _count(conn, "osm_crossings"),
        )

        # 적재된 길을 교차점을 기준으로 잘라서 적재하는 함수 호출
        split_ways(conn)

    finally:
        conn.close()


if __name__ == "__main__":
    main()

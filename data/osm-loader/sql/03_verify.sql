-- ============================================================
-- 03_verify.sql: 적재 결과 검증 쿼리 모음
-- 사용법: docker exec -i localPostgis psql -U root -d running < sql/03_verify.sql
-- ============================================================

-- 1. 총 적재 건수
SELECT
    'osm_ways'     AS tbl, COUNT(*) AS cnt FROM osm_ways
UNION ALL
SELECT
    'osm_crossings', COUNT(*) FROM osm_crossings;

-- 2. highway 종류별 분포
SELECT highway, COUNT(*) AS cnt
FROM osm_ways
GROUP BY highway
ORDER BY cnt DESC;

-- 3. 공간 인덱스 동작 확인 (마포구 중심 1km 반경 내 way)
-- 상암동 월드컵공원 근처 좌표 기준
EXPLAIN ANALYZE
SELECT osm_id, highway, name
FROM osm_ways
WHERE ST_DWithin(
    geom::geography,
    ST_SetSRID(ST_MakePoint(126.8875, 37.5683), 4326)::geography,
    1000  -- 미터
);

-- 4. 횡단보도와 5m 내 way 연결 확인 (연결성 검증 기본 동작)
SELECT c.osm_id AS crossing_id, w.osm_id AS way_id, w.highway
FROM osm_crossings c
JOIN osm_ways w
  ON ST_DWithin(c.geom::geography, w.geom::geography, 5)
LIMIT 10;

-- 5. geometry 유효성 검증 (모두 ST_IsValid = true 여야 함)
-- 결과가 0이어야 정상
SELECT COUNT(*) AS invalid_geom_count
FROM osm_ways
WHERE NOT ST_IsValid(geom);

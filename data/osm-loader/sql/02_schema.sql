-- ============================================================
-- districts: 행정 구역
-- ============================================================
CREATE TABLE IF NOT EXISTS districts (
    district_id   CHAR(5)     PRIMARY KEY,               -- 행정구역코드 앞 5자리 (예: '11440')
    sido          VARCHAR(50) NOT NULL,
    gu            VARCHAR(50) NOT NULL,
    center_point  GEOMETRY(POINT,   4326),               -- 기상청 격자 위경도 기준
    boundary      GEOMETRY(POLYGON, 4326)                -- Overpass 행정 경계
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_districts_sido_gu
    ON districts(sido, gu);

CREATE INDEX IF NOT EXISTS idx_districts_boundary
    ON districts USING GIST(boundary);


-- ============================================================
-- osm_ways: 보행 가능 도로 세그먼트
-- ============================================================
CREATE TABLE IF NOT EXISTS osm_ways (
    osm_id      BIGINT          PRIMARY KEY,          -- OSM way ID (전역 고유)
    highway     VARCHAR(50)     NOT NULL,             -- 도로 분류
    name        VARCHAR(255),                         -- 도로명
    geom        GEOMETRY(LINESTRING, 4326) NOT NULL,  -- 좌표계: WGS84

    -- 통행 제어 (검증 로직에 직접 사용)
    foot        VARCHAR(20),    -- yes / no / designated / permissive
    access      VARCHAR(20),    -- yes / no / private / customers
    oneway      VARCHAR(10),    -- yes / no / -1

    -- 구조 속성 (GPS 끊김 구간 면책 처리용)
    bridge      BOOLEAN         DEFAULT FALSE,
    tunnel      BOOLEAN         DEFAULT FALSE,
    indoor      BOOLEAN         DEFAULT FALSE,
    layer       SMALLINT        DEFAULT 0,

    -- 러닝 UX 속성 (MVP 이후 기능용이나 지금 같이 적재)
    surface     VARCHAR(30),    -- asphalt / concrete / dirt ...
    lit         BOOLEAN,        -- 야간 안전 경로용
    sidewalk    VARCHAR(20),    -- both / left / right / none

    -- 고도 관련 컬럼 (loader/main.py 실행 시 적재)
    elevation_nodes     JSONB,      -- [{lng, lat, elev}, ...] 노드별 고도값
    elevation_gain      FLOAT8,     -- 고도 상승량 (m), 오르막 구간 합산
    avg_uphill_grade    FLOAT8,     -- 오르막 평균 경사도 (%), 오르막 구간만

    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 공간 인덱스 (geometry — 평면 좌표계 쿼리용)
CREATE INDEX IF NOT EXISTS idx_osm_ways_geom
    ON osm_ways USING GIST(geom);

-- 공간 인덱스 (geography — 미터 단위 ST_DWithin/ST_Distance용 함수 인덱스)
-- ST_DWithin(geom::geography, point::geography, meters) 형태가 인덱스를 타려면
-- 캐스팅된 식 자체에 GIST가 걸려있어야 함.
CREATE INDEX IF NOT EXISTS idx_osm_ways_geom_geog
    ON osm_ways USING GIST((geom::geography));

-- 도로 종류별 필터링용
CREATE INDEX IF NOT EXISTS idx_osm_ways_highway
    ON osm_ways(highway);


-- ============================================================
-- osm_crossings: 횡단보도 노드
-- 경로 생성·검증 시 도보 가능한 way 간 연결 판단에 사용
-- ============================================================
CREATE TABLE IF NOT EXISTS osm_crossings (
    osm_id      BIGINT          PRIMARY KEY,          -- OSM node ID (전역 고유)
    crossing    VARCHAR(30),    -- marked / unmarked / zebra / traffic_signals
    has_signals BOOLEAN         DEFAULT FALSE,
    geom        GEOMETRY(POINT, 4326) NOT NULL,

    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_osm_crossings_geom
    ON osm_crossings USING GIST(geom);

CREATE INDEX IF NOT EXISTS idx_osm_crossings_geom_geog
    ON osm_crossings USING GIST((geom::geography));


CREATE TABLE IF NOT EXISTS osm_ways_split (
    id              BIGINT          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_osm_id   BIGINT          NOT NULL REFERENCES osm_ways(osm_id),
    geom            GEOMETRY(LINESTRING, 4326) NOT NULL
);

-- postgre는 내부적으로 fk에 자동으로 인덱스를 만들어주지 않음(mysql은 걸어줌)
CREATE INDEX IF NOT EXISTS idx_osm_ways_split_source
    ON osm_ways_split(source_osm_id);

CREATE INDEX IF NOT EXISTS idx_osm_ways_split_geom
    ON osm_ways_split USING GIST(geom);
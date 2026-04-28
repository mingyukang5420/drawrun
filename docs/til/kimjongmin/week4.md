# 2026-04-27

## Postgre, Postgis 입문

### GEOMETRY

- PostGIS에서 지원하는 타입으로 공간 정보를 DB에 저장하기 위한 데이터 타입
  
  - 점 하나(POINT): `(126.9236, 37.5566)  ← 횡단보도 위치`
  
  - 선(LINESTRING): `(126.9236, 37.5566) → (126.9241, 37.5570) → (126.9250, 37.5575) <- 도로 하나`
  
  - 면(POLYGON): `(126.92, 37.55) → (126.93, 37.55) → (126.93, 37.56) → (126.92, 37.56) → (126.92, 37.55) ← 공원 경계선 (시작점 = 끝점으로 닫힌 도형)`

- 위의 것들을 일반 컬럼에 저장하려면?

```sql
-- 이렇게 하면 공간 쿼리가 불가능함
lat1 FLOAT, lon1 FLOAT,
lat2 FLOAT, lon2 FLOAT,
lat3 FLOAT, lon3 FLOAT ...
```

-> 점이 몇 개인지도 모르기 때문에 컬럼을 미리 만들어 둘 수 없음. GEOMETRY 타입은 이 문제를 해결하여 **좌표 몇개짜리든 하나의 컬럼에 통째로 저장하고, 그 위에서 공간 연산까지 가능하게 함**

### GEOMETRY 선언 문법

```sql
geom GEOMETRY(LINESTRING, 4326)
```

- 인자를 두 개 받음
  
  - 첫 번째 인자
    
    - POINT: 점 하나(횡단보도 등)
    
    - LINESTRING: 이어진 선(도로 등)
    
    - POLYGON: 닫힌 면(공원의 경계 등)
    
    - GEOMETRY: 타입 제한 없음(타입 불일치 에러를 잡을 수 없어 비추천)
  
  - 두 번째 인자
    
    - SRID: Spatial Reference ID. 좌표계를 구분하는 번호

- 실제 컬럼에 들어가는 값 예시
  
  - ```sql
    LINESTRING(126.9236 37.5566, 126.9241 37.5570, 126.9250 37.5575)
                ↑lon   ↑lat      ↑lon   ↑lat
    ```
  
  - **경도 먼저, 위도가 나중** 일상적으로 위도, 경도로 말하는 것과 순서가 반대임을 주의해야 함
  
  - 실제 DB에 저장될 때는 바이너리(WKB) 형식으로 변환돼서 삽입됨. 
  
  - ```sql
    SELECT geom FROM osm_ways
    -- 0102000020E6100000030000009A9999999999...
    ```
  
  - `ST_AsText(geom)` 함수를 사용하여 사람이 읽을 수 있는 데이터로 출력
  
  - ```sql
    SELECT ST_AsText(geom) FROM osm_ways LIMIT 1;
    -- LINESTRING(126.9236 37.5566, 126.9241 37.5570, ...)
    ```

### GEOMETRY 활용

- 단순하게 타입만 저장하는 것이 아닌 **연산**이 가능해짐

**ST_DWithin — "이 좌표가 도로에서 N미터 이내인가?"**

```sql
SELECT osm_id, highway
FROM osm_ways
WHERE ST_DWithin(
    geom::geography,
    ST_SetSRID(ST_MakePoint(126.9236, 37.5566), 4326)::geography,
    15  -- 15미터 이내
);
```

- `ST_MakePoint(lon, lat)` → 좌표 두 개로 POINT 만들기
- `ST_SetSRID(..., 4326)` → "이 점은 4326 좌표계야"라고 명시
- `::geography` → 미터 단위 계산을 위한 캐스팅 (아래에서 자세히 설명)
- `ST_DWithin(A, B, 15)` → A와 B 사이가 15미터 이내면 TRUE
  - 사용자 GPS 좌표를 B 자리에 넣으면 **도로 위에 있나?**를 판별할 수 있음

**ST_Distance — "두 점 사이 거리가 얼마나?"**

```sql
SELECT ST_Distance(
    geom::geography,
    ST_SetSRID(ST_MakePoint(126.9236, 37.5566), 4326)::geography
) AS distance_meters
FROM osm_crossings
ORDER BY distance_meters
LIMIT 5;  -- 가장 가까운 횡단보도 5개
```

**ST_Intersects — "두 도로가 교차하나?"**

```sql
SELECT a.osm_id, b.osm_id
FROM osm_ways a, osm_ways b
WHERE ST_Intersects(a.geom, b.geom)
  AND a.osm_id != b.osm_id;
```

### ::geography 캐스팅

```sql
ST_DWithin(geom::geography, 점::geography, 15)
```

- `::geography`를 왜 붙이는가?
  
  - 붙이지 않는다면?
  
  - ```sql
    -- geography 없이
    ST_DWithin(geom, 점, 15)
    ```
  
  - 이러면 15의 단위가 도(degree)가 돼버림. 위도/경도는 도 단위로 이루어져 있음
  
  - 15도 = 지구 표면에서 약 1,670km
  
  - 15미터 이내 대신 1,670km 이내로 검색하게 됨

- geometry -> 지구를 평평한 평면으로 보고 계산함
  
  - 두 점 사이의 거리 공식으로 계산됨(단위는 저장된 좌표계 단위로 사용함)

- geography -> 지구를 구로 보고 계산함
  
  - 두 점 사이 거리 = 구면 위의 호의 길이(단위는 항상 미터)

- 의문
  
  - 왜 저장한 geometry로 하고 계산 할 때만 geography로 캐스팅 하는가?
  
  - 1. GIST 인덱스 호환성: geometry 타입에 거는 GIST 인덱스가 더 성숙하고 빠름. geometry쪽이 지원하는 함수가 더 많음
    
    2. 연산 속도: geography는 구면 계산이라 geometry보다 느림
    
    3. 필요한 곳에서만 미터 단위 사용: **15미터 이내** 같은 거리 기반 판별에서만 `::geography` 를 붙여, 빠르고 편리하게 사용하다가 필요할 때만 geometry로 변환하여 거리 계산

- 실제 사용 차이 예시

```sql
-- geometry (평면, 단위: 도)
SELECT ST_Distance(
    ST_MakePoint(126.9779, 37.5663),  -- 시청
    ST_MakePoint(126.9769, 37.5760)   -- 광화문
);
-- 결과: 0.00977... (도 단위. 이게 몇 미터인지 바로 알 수 없음)

-- geography (구면, 단위: 미터)
SELECT ST_Distance(
    ST_MakePoint(126.9779, 37.5663)::geography,
    ST_MakePoint(126.9769, 37.5760)::geography
);
-- 결과: 1088.3... (미터. 약 1.1km. 바로 이해 가능)
```

> geometry는 저장용 타입, geography는 "미터 단위로 계산하고 싶을 때" 잠깐 빌려 쓰는 타입. `::geography`는 그 순간의 형변환이다.

### GIST 인덱스

```sql
CREATE INDEX IF NOT EXISTS idx_osm_ways_geom
    ON osm_ways USING GIST(geom);

CREATE INDEX IF NOT EXISTS idx_osm_ways_highway
    ON osm_ways(highway);
```

**GIST 인덱스 vs 일반 B-tree 인덱스**

- 일반 인덱스는 B-tree 구조로, 숫자나 문자열 같은 1차원 데이터를 정렬해서 빠르게 찾음. 예를 들어 36 보다 큰 숫자 같은 비교는 굉장히 빠르고 잘 됨

- 하지만 **특정 좌표에서 100m 이내** 라는 비교는 2차원 공간 비교임. B-tree 기반의 인덱스로는 이걸 빠르게 할 수 없음

- GIST: 공간 데이터를 위한 인덱스. 내부적으로 R-tree라는 구조로 공간을 박스 단위로 나눠서 관리함. **이 영역 안에 있는 것들** 을 빠르게 좁혀 나갈 수 있음

```textile
전체 마포구
  └─ 합정동 영역
       └─ 합정역 반경 500m
            └─ 내가 찾는 도로들
```

이런 식으로 범위를 좁혀 찾아가면서 데이터를 풀스캔 할 필요 없음

GIST 인덱스 VS B-tree

- B-tree는 1차원 데이터 정렬 기반이라 공간 쿼리에 적합하지 않음. GIST는 R-tree 계열로 2D 박스를 트리화 해서 공간 범위 탐색에 최적화됨

## LINESTRING

- 직선 사이의 모든 노드가 저장되는것이 아닌 꺾이는 지점의 좌표만 저장됨

```textile
A(126.92, 37.55) → B(126.93, 37.56) → C(126.94, 37.55)
```

```sql
LINESTRING(126.92 37.55, 126.93 37.56, 126.94 37.55)
```

- A -> B 사이, B -> C 사이의 무한한 중간 점들은 저장하지 않고, **A에서 B로 직선으로 이어진다.** 라는 약속만 저장함

**곡선 도로의 경우는?**

- 실제 도로는 보통 곡선으로 이루어진 경우가 많음. -> 꺾이는 점을 촘촘하게 많이 찍어서 곡선처럼 보이게 함

```textile
실제 곡선 도로:

     ●───●
    ●     ●
   ●       ●
  ●         ●

저장되는 것: ● 표시된 좌표들만
렌더링할 때: 그 점들을 직선으로 이어서 곡선처럼 보여줌
```

- 점이 많을수록 곡선이 부드럽게 보이고, OSM에서 직선 도로는 시작점 - 끝점 2개, 곡선 도로는 수십 ~ 수백 개의 좌표를 저장함

### ST_DWithin

- **GPS 좌표가 도로에서 15m 이내인가?** 를 판별할 때, PostGIS는 점과 LINESTRING 사이의 최단 거리를 계산함

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

---

## 2026-04-28

## 컨버터 패턴

- 객체를 다른 타입의 객체로 변환하는 책임을 별도 클래스로 분리하는 패턴

- 변환이 필요한 상황

- ```textile
  요청 DTO → 도메인 엔티티   (Controller에서 받은 것을 Service/DB용으로)
  도메인 엔티티 → 응답 DTO   (DB에서 꺼낸 것을 클라이언트에 내려줄 형태로)
  ```

-> 같은 엔티티를 여러 DTO로 변환해야 할 때

-> 변환 로직이 복잡하고 길어질 때

-> 변환 로직을 독립적으로 테스트하고 싶을 때 사용

## GEOMETRY 타입

LINESTRING은 java의 기본 타입이 아님. JPA가 모르는 타입이라 별도 의존성과 설정이 필요함

`implementation 'org.hibernate.orm:hibernate-spatial'`

JPA는 Java 객체 ↔ DB 컬럼 변환을 어떻게 하는지 알고 있어야 함

`String → VARCHAR`, `Long → BIGINT`는 JPA가 기본으로 알고 있음`GEOMETRY(LINESTRING)` 은 표준 SQL 타입이 아님 -> 별도의 의존성이 필요함

`implementation 'org.locationtech.jts:jts-core:1.19.0'`

LineString 같은 클래스를 제공하는 라이브러리.

## GIST 인덱스 관리

GIST 인덱스는 ddl auto 옵션을 어떤걸로 두던지, JPA가 생성하지 못함. 즉 관련 DDL문은 수동으로 한번 실행이 필요함

# JPA 엔티티 설계 학습 정리

## 1. 의존성 설정

### 1-1. Hibernate Spatial

PostGIS의 `GEOMETRY` 타입은 표준 SQL 타입이 아니다.  
JPA는 기본적으로 `String → VARCHAR`, `Long → BIGINT` 같은 표준 타입 변환만 알고 있다.  
**Hibernate Spatial**은 PostGIS의 `GEOMETRY` 타입을 JPA가 다룰 수 있도록 변환 방법을 가르쳐주는 라이브러리다.

```gradle
implementation 'org.hibernate.orm:hibernate-spatial'  // Spring Boot가 버전 자동 관리
implementation 'org.locationtech.jts:jts-core:1.19.0' // LineString, Point 클래스 제공
```

- `hibernate-spatial` : JPA ↔ PostGIS GEOMETRY 변환 담당
- `jts-core` : Java 코드에서 `LineString`, `Point` 타입을 직접 쓰기 위해 필요

### 1-2. application.yml

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/your_db
    username: your_username
    password: your_password
    driver-class-name: org.postgresql.Driver

  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: update
    properties:
      hibernate:
        format_sql: true
    show-sql: true
```

---

## 2. ddl-auto 옵션

| 옵션         | 동작                          | 문제점                             |
| ---------- | --------------------------- | ------------------------------- |
| `create`   | 앱 실행 시 테이블 새로 생성            | 기존 데이터 전부 삭제                    |
| `update`   | 새 테이블/컬럼만 추가, 기존 건드리지 않음    | 컬럼 삭제/타입 변경은 반영 안 됨             |
| `validate` | 엔티티와 테이블 구조 불일치 시 실행 자체를 막음 | GEOMETRY 타입 매핑 불일치로 실행 안 될 수 있음 |
| `none`     | JPA가 DDL 전혀 건드리지 않음         | 팀원이 JPA로 테이블 생성 불가              |

### 이 프로젝트에서 `update`를 선택한 이유

- `none` : 다른 팀원이 JPA로 테이블을 만들 수 없어서 탈락
- `validate` : GEOMETRY 타입 매핑 불일치로 앱 실행 자체가 막힐 수 있어서 탈락
- `update` : 새로운 테이블은 JPA가 자동 생성해주고, GIST 인덱스처럼 JPA가 모르는 구문은 건드리지 않아서 선택

### `update`의 한계

컬럼 삭제나 타입 변경은 반영되지 않는다.  
엔티티에서 필드를 지워도 DB 컬럼은 그대로 남는다.

> **현업에서는** Flyway, Liquibase 같은 마이그레이션 툴로 SQL 파일을 버전 관리한다.  
> 지금 단계에서는 과하므로 GIST 인덱스 DDL은 수동으로 한 번 실행하는 것으로 대체한다.

---

## 3. 인덱스

### 3-1. 인덱스가 없을 때 — Full Table Scan

```sql
SELECT * FROM osm_ways WHERE highway = 'footway';
```

인덱스가 없으면 DB는 **첫 번째 행부터 마지막 행까지 전부 읽는다.**  
마포구 데이터가 10만 건이면 10만 건을 다 뒤집는다. 이를 **Full Table Scan** 이라고 한다.

### 3-2. 인덱스가 있을 때

인덱스는 **별도로 만들어두는 정렬된 사전**이다.  
`highway` 컬럼에 인덱스를 걸면 DB가 이런 구조를 따로 만들어둔다.

```
[ 인덱스 구조 — B-Tree ]
cycleway  → 3번행, 17번행, 45번행 ...
footway   → 2번행, 8번행, 23번행 ...
path      → 5번행, 11번행, 39번행 ...
primary   → 1번행, 6번행, 14번행 ...
```

`highway = 'footway'` 를 찾으면 사전에서 `footway`를 바로 찾아서 해당 행으로 바로 점프한다.

### 3-3. 인덱스 동작 정리

| 상황                           | 동작                     |
| ---------------------------- | ---------------------- |
| `WHERE id = ?` (PK)          | PK는 자동으로 인덱스 생성 → 빠름   |
| `WHERE highway = ?` (인덱스 있음) | 인덱스 탐 → 빠름             |
| `WHERE highway = ?` (인덱스 없음) | Full Table Scan → 느림   |
| `WHERE name LIKE '%로%'`      | 인덱스 있어도 Full Scan → 느림 |

> `LIKE '%값%'` 처럼 앞에 `%`가 붙으면 인덱스를 타지 못한다.  
> 사전에서 단어 중간 글자로는 찾지 못하는 것과 같은 원리다.

### 3-4. 인덱스의 단점

모든 컬럼에 인덱스를 걸면 좋을 것 같지만 단점이 있다.

- INSERT/UPDATE/DELETE 시 인덱스 구조도 같이 업데이트 → **쓰기 성능 저하**
- 인덱스 자체의 **추가 저장 공간** 필요

그래서 인덱스는 이런 컬럼에 건다.

- 조회 조건으로 **자주 쓰이는** 컬럼 (`WHERE highway = ?`)
- 데이터 **종류가 다양한** 컬럼 (종류가 2~3개뿐이면 효과 적음)
- 데이터가 **많은** 테이블

### 3-5. B-Tree vs GIST

|             | **B-Tree**               | **GIST**                      |
| ----------- | ------------------------ | ----------------------------- |
| **구조**      | 정렬된 트리                   | 공간 분할 트리                      |
| **적합한 데이터** | 숫자, 문자열                  | 좌표, 도형                        |
| **지원 연산**   | `=`, `<`, `>`, `BETWEEN` | `ST_DWithin`, `ST_Intersects` |

B-Tree는 대소 비교에 최적화되어 있다.  
좌표 데이터는 "이 박스 안에 있는 도형"을 찾아야 하는데 대소 비교로는 표현이 안 된다.  
GIST는 공간을 분할해서 저장하기 때문에 공간 쿼리가 빠르다.

### 3-6. JPA에서 인덱스 거는 법

```java
@Table(name = "osm_ways", indexes = {
    @Index(name = "idx_osm_ways_highway", columnList = "highway")
})
```

`@Index`는 `ddl-auto: update` 설정 시 앱 실행 시점에 아래 SQL을 자동 실행한다.

```sql
CREATE INDEX idx_osm_ways_highway ON osm_ways(highway);
```

**단, `@Index`는 B-Tree 인덱스만 지원한다.**  
GIST 같은 특수 인덱스 타입을 지정하는 옵션이 없다.

### 3-7. GIST 인덱스 — 수동 실행 필요

JPA가 표현하지 못하는 인덱스는 SQL로 직접 실행한다.  
팀원들이 각자 로컬 DB에 한 번씩 실행하면 된다.

```sql
-- osm_ways GIST 인덱스
CREATE INDEX IF NOT EXISTS idx_osm_ways_geom
    ON osm_ways USING GIST(geom);

CREATE INDEX IF NOT EXISTS idx_osm_ways_geom_geog
    ON osm_ways USING GIST((geom::geography));

-- osm_crossings GIST 인덱스
CREATE INDEX IF NOT EXISTS idx_osm_crossings_geom
    ON osm_crossings USING GIST(geom);

CREATE INDEX IF NOT EXISTS idx_osm_crossings_geom_geog
    ON osm_crossings USING GIST((geom::geography));
```

`IF NOT EXISTS` 가 붙어있어서 이미 있어도 에러가 나지 않는다.

### 3-8. 이 프로젝트 인덱스 관리 방법 정리

| 인덱스                           | 방법                   | 이유                    |
| ----------------------------- | -------------------- | --------------------- |
| `idx_osm_ways_highway`        | `@Index` — JPA 자동 생성 | 일반 B-Tree라 JPA가 표현 가능 |
| `idx_osm_ways_geom`           | SQL 직접 실행            | GIST라 JPA가 표현 불가      |
| `idx_osm_ways_geom_geog`      | SQL 직접 실행            | GIST라 JPA가 표현 불가      |
| `idx_osm_crossings_geom`      | SQL 직접 실행            | GIST라 JPA가 표현 불가      |
| `idx_osm_crossings_geom_geog` | SQL 직접 실행            | GIST라 JPA가 표현 불가      |

---

## 4. columnDefinition

JPA가 엔티티 필드를 보고 DB 컬럼을 생성할 때 쓸 **DDL 구문을 직접 지정**하는 속성이다.

### JPA가 타입을 자동으로 결정하는 경우

```java
private String name;          // → VARCHAR(255)
private Long id;              // → BIGINT
private Boolean bridge;       // → BOOLEAN
private LocalDateTime createdAt; // → TIMESTAMP
```

이런 표준 타입은 JPA가 Java 타입을 보고 DB 타입을 알아서 결정한다.

### columnDefinition이 필요한 경우

```java
// 1. PostGIS처럼 표준이 아닌 타입
// JPA가 LineString → DB 타입 자동 변환 불가
// 4326이라는 좌표계 정보를 JPA가 추론할 방법 없음
@Column(columnDefinition = "geometry(LineString, 4326)")
private LineString geom;

// 2. 기본 DDL이 원하는 것과 다를 때
// JPA는 String을 VARCHAR(255)로 만드는데 TEXT로 만들고 싶다면
@Column(columnDefinition = "TEXT")
private String content;

// 3. DB 레벨 default값을 지정하고 싶을 때
@Column(columnDefinition = "BOOLEAN DEFAULT FALSE")
private Boolean bridge;
```

### 주의점

`columnDefinition`에 쓴 구문은 **DB 종속적**이다.  
PostgreSQL에서 `geometry(LineString, 4326)`이 동작한다고 MySQL에서도 되는 게 아니다.  
`columnDefinition`을 많이 쓸수록 특정 DB에 묶이게 되므로 꼭 필요한 경우에만 쓴다.

---

## 5. @GeneratedValue와 @PrePersist 제거 이유

이 테이블은 OSM 외부 데이터를 적재하는 **읽기 전용 테이블**이다.  
JPA를 통해 INSERT할 일이 없다.

**`@GeneratedValue` 제거 이유**

- JPA를 통해 INSERT하지 않으니 JPA가 시퀀스를 관리할 필요가 없다
- `id`는 DDL의 `BIGSERIAL`로 DB가 자동 생성한다

**`@PrePersist` + `createdAt` 자동 생성 제거 이유**

- `@PrePersist`는 JPA로 INSERT할 때 동작하는 훅이다
- INSERT할 일이 없으니 동작할 일도 없다
- `created_at`은 DDL의 `DEFAULT CURRENT_TIMESTAMP`로 DB가 처리한다

# **ST_Intersects**

- 두 도형이 겹치는지 여부를 boolean 타입으로 반환하는 PostGIS 함수
  
  ```sql
  ST_Intersects(도형A, 도형B) → true / false
  ```

- **겹친다**의 의미?
  
  - 두 도형이 공간적으로 공유하는 점이 하나라도 있다면 true
  
  - ```textile
    케이스 1 — 완전히 안에 있을 때 → true
    ┌──────────────┐
    │              │
    │   ~~~~~~~~   │  (도로가 bbox 안에 완전히 있음)
    │              │
    └──────────────┘
    
    케이스 2 — 경계를 걸칠 때 → true
    ┌──────────────┐
    │              │
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~  (도로가 bbox 경계를 넘어감)
    │              │
    └──────────────┘
    
    케이스 3 — 완전히 밖에 있을 때 → false
    ┌──────────────┐
    │              │
    │              │   ~~~~~~~~  (도로가 bbox 밖에 있음)
    └──────────────┘
    ```

- 케이스 2의 경우, 화면 가장자리의 도로가 잘려보이지 않게 하기 위해 일단 범위 안에 들어오는 도로는 끝까지 로드 할 목적으로 ST_Within 함수 대신 선택

# ST_MakeEnvelope

- 4개의 좌표값을 받아서 직사각형 도형을 만들어주는 PostGIS 함수

- ```sql
  ST_MakeEnvelope(minX, minY, maxX, maxY, SRID)
  ```

```textile
(maxLat, maxLng) ─────────────┐
                  │            │
                  │  Envelope  │
                  │            │
                  └──────────── (minLat, minLng)
```

- 실제 예시

- ```sql
  ST_MakeEnvelope(126.90, 37.54, 126.94, 37.57, 4326)
  --              minLng  minLat  maxLng  maxLat  좌표계
  ```

- 마지막 4326은 좌표계를 의미함

---

# # 2026-04-29

## JWT 로그인

Spring Security + JWT 요청/응답 체인

```textile
Client Request
     │
     ▼
┌─────────────────────────────────────────┐
│           Servlet Container             │  ← Tomcat (가장 바깥)
│                                         │
│  ┌──────────────────────────────────┐   │
│  │     DelegatingFilterProxy        │   │  ← Spring이 Servlet Filter에 끼어드는 입구
│  │                                  │   │
│  │  ┌────────────────────────────┐  │   │
│  │  │   FilterChainProxy         │  │   │  ← Security Filter들의 관리자
│  │  │                            │  │   │
│  │  │  1. SecurityContextHolder  │  │   │  ← 인증 정보 저장소 (ThreadLocal)
│  │  │  2. UsernamePasswordAuth.. │  │   │  ← Form 로그인용 (우리는 커스텀으로 대체)
│  │  │  3. [JwtAuthFilter]  ★     │  │   │  ← 우리가 만들 필터
│  │  │  4. ExceptionTranslation   │  │   │  ← 인증 예외 처리
│  │  │  5. FilterSecurityInterc.. │  │   │  ← 인가(Authorization) 체크
│  │  └────────────────────────────┘  │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │       DispatcherServlet          │   │  ← Filter 통과 후 여기 도달
│  │                                  │   │
│  │   HandlerMapping                 │   │  ← 어떤 Controller로 갈지
│  │   HandlerInterceptor             │   │  ← Controller 전/후 가로채기
│  │   Controller                     │   │  ← 실제 비즈니스 로직
│  │   Service / Repository           │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
     │
     ▼
Client Response
```

## 인증이 필요한 요청 흐름

1. [Filter 레벨] JwtAuthFilter ← 핵심
   → Header에서 "Bearer {accessToken}" 추출
   → JWT 서명 검증 + 만료 검사
   → 유효하면 → SecurityContextHolder에 Authentication 저장

2. [Filter 레벨] FilterSecurityInterceptor
   → SecurityContext에 인증 정보 있는지 확인
   → 권한(ROLE) 체크

3. [Controller 레벨] 도달
   → @AuthenticationPrincipal 등으로 유저 정보 꺼내 사용

## CSRF 옵션을 끄는 이유는?

### CSRF 공격 성립 조건

1. 피해자가 A 사이트에 로그인 된 상태

2. 악성 사이트 B 에서 A 사이트로 요청을 유도

3. 브라우저가 A 사이트의 쿠키를 자동으로 실어서 전송

4. 서버는 쿠키가 있으니 정상 요청으로 판단 -> 공격 성공

-> 브라우저가 쿠키를 자동으로 붙여줌

하지만 JWT 방식의 인증 방식은 쿠키가 아닌 헤더로 인증을 하기 때문에 csrf 공격 수법으로는 토큰을 모르기 때문에 공격 방식이 성립이 안됨

---

# 2026-04-30

- 기존에 적재해뒀던 OSM 데이터들이 다른 길로 이어지는 교차점들에 대한 정보는 제공하지 못한다고 판단함

- 기존 OSM 테이블의 선분들 간 교차점을 찾아 교차점을 기준으로 linestring 선분을 끊어 전처리하는 로직 추가

- 테이블은 하나로 두지 않고 OSM 원본 데이터와 분리하였는데 그 이유는 다음과 같음
  
  - pk 결정 문제: som_ways 테이블의 컬럼들을 세세하게 쪼개는 작업이 진행되어야 하기 때문에 osm 측에서 내려주는 pk 값을 사용할 수 없음. 이 시점에서 osm_id로 원본을 추적할 수 없어짐.(지도 정보 업데이트 불가능) som_id 컬럼을 별도로 추가하는 방법도 있지만 원본 테이블과 동일한 중복되는 데이터가 많아진다는 무제가 발생함. 또한 원본 테이블에서 다른 속석들이 바뀌면 쪼개진 테이블도 같이 바꿔야하는데 이과정에서 갱신이상이 발생 할 위험이 높아보였음
  
  - 분리해도 join 과정의 부담이 없음. fk가 정수형이고 이 컬럼에 인덱스가 걸려있다면 join 비용은 거의 무시할 수 있는 수준임

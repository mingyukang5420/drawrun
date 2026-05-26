# 2026-04-20

- 팀 미팅 및 기획 주제 변경

- 기획 주제: 드로잉 런

---

# 2026-04-21

- 기획 아이디어 구체화 진행

---

# 2026-04-22

- 구체화된 기획 아이디어를 바탕으로 서비스 플로우 설계

- 문서화 진행(API 명세서 및 와이어프레임)

---

# 2026-04-23

#### 오늘 한 일 (What I did)

- ERD 작업 마무리 및 팀 내부 미팅 요청

- ERD 설계 방향 팀 내 의견 공유 및 합의

- API 명세서 팀 전체 검토 및 싱크 미팅 진행

---

#### 배운 것 (What I learned)

- 생각보다 다들 생각하고 있는 플로우가 달라서 중간에 한번은 반드시 다같이 생각을 통일하고 가는 과정이 필요하다고 느꼈다.

---

# 2026-04-24

# TIL — 서울 전역 보행 가능 길 시각화 POC 회고

> 카카오 지도 위에 "도보로 갈 수 있는 모든 길"을 렌더링하는 작업.
> 러닝 서비스(경로 생성·추종·자율 러닝 검증, 드로잉 런)의 **지도 데이터 기반**이 실현 가능한지 확인하는 것이 이 POC의 유일한 목적이었다.

- **작성일:** 2026-04-24
- **프로젝트 루트:** `C:\Users\SSAFY\Desktop\map-data-poc\`
- **실행 주소:** `http://127.0.0.1:8000/` (반드시 `127.0.0.1`, localhost 아님 — 5-3 참조)
- **Django 버전:** 4.2.x
- **DB:** SQLite (`db.sqlite3`, 재적재 시 재생성)
- **Git 상태:** 저장소 초기화되지 않음 — til.md와 소스 코드 자체가 버전 기록 역할

---

## 1. 한눈에 보는 요약 (TL;DR)

- **두 개의 POC를 연달아 했다**: (1) 공공데이터 중심 레거시 POC — 커버리지 부족으로 중단. (2) OSM 단일 소스 POC — 서울 전역 166,170건 적재, 뷰포트 기반 실시간 렌더링 성공.
- **핵심 기술 결정**: 도로 필터링 키를 **중심점에서 bbox(min/max lat·lng) 4필드로 교체** — 긴 도로가 확대 시 끊기던 현상 원천 차단. 이게 이 POC의 가장 중요한 단일 결정.
- **UX 결정**: `map.idle` 이벤트 + 200ms 디바운스, Polyline diff(재사용), AbortController 조합으로 **깜빡임/끊김 없는 줌·팬**을 확보.
- **한계(의도적)**: 이 POC에는 그래프 구조(노드·엣지), 공간 인덱스(PostGIS), map matching이 없다. 향후 기능(경로 자동 생성·러닝 검증·드로잉 런)은 별도 단계에서 착수.

---

## 2. 왜 이 POC를 했는가

### 2-1. 최종 목적

최종 서비스는 **러닝용 지도 앱**이다. 사용자는 세 가지 경험을 한다:

1. **지도에 자유롭게 경로를 그려 러닝 코스를 만든다.** (일반 러닝 + **드로잉 런** — GPS 궤적으로 동물·글자 등을 그리는 경험)
2. **그 경로대로 뛰었는지 검증**받는다. (경로 추종)
3. **코스 없이 자율 러닝**했을 때도, 도보 가능한 길만 이용했는지 사후 검증받는다.

세 경험 모두 **"어떤 길이 도보로 갈 수 있는가"**에 대한 정확한 지도 데이터가 출발점이다. 데이터가 없으면 위 기능은 전부 불가능하다.

### 2-2. POC로 검증할 단일 가설

> **"서울 전역의 도보 가능 길 전체를, 러닝 서비스에 쓸 수 있을 만큼 촘촘하고 정확하게, 적절한 비용으로 확보할 수 있는가?"**

여기서의 "도보 가능 길"은 인도·광장·계단·골목·이면도로·한강 자전거겸용로·산책로까지 포함된 **보행자가 합법적으로 지나갈 수 있는 모든 선형 공간**이다.

### 2-3. 이 POC가 증명하지 않는 것

- 경로 자동 탐색(라우팅)
- 러닝 검증(map matching)
- 드로잉 런의 형상 재현 품질
- 사용자 관리·인증·세션

이들은 뒤에 별도 단계에서 다룬다. 이 POC의 결론이 "데이터 불가능"으로 나오면 위 기능 개발 자체가 무의미하므로 먼저 데이터 층부터 검증한다.

---

## 3. 레거시 POC (공공데이터 기반) — `legacy/` 아카이브

### 3-1. 설계 요약

데이터 소스로 **공공데이터포털 3종 + OSM 보조**를 사용했다:

| 테이블                        | 소스            | 기하          | 용도          |
| -------------------------- | ------------- | ----------- | ----------- |
| `crosswalk`                | 공공데이터포털       | Point       | 무단횡단 판별     |
| `pedestrian_only_road`     | 공공데이터포털       | 2점 Line     | 보행 전용 도로    |
| `pedestrian_priority_road` | 공공데이터포털       | 2점 Line     | 보행자 우선 도로   |
| `walkable_road`            | OpenStreetMap | N점 Polyline | 포괄 보행 가능 도로 |

화면 기능: 카카오 지도 + 공공데이터 마커·폴리라인 + OSM 오버레이 + 무단횡단 판별 폼 + 생활안전지도(safemap) WMS 프록시 레이어.

### 3-2. 한계 — 정량 데이터

강남구(역삼동 중심) 실측에서 공공데이터의 커버리지 부족이 **숫자로 확정**됐다:

| 데이터      | 강남구 결과        | 문제                               |
| -------- | ------------- | -------------------------------- |
| 보행자전용도로  | **2건 (개포동만)** | 역삼동 데이터 전무                       |
| 보행자우선도로  | 6건            | 일부만 등록                           |
| **횡단보도** | **0건**        | 강남구 완전 미등록. 서울 내 동작구(1,057건)만 등록 |

OSM은 같은 지역에서 보행 가능 도로 **184,116건**(서울 전역)을 커버했고, 골목·계단·한강 산책로까지 포함했다.

### 3-3. 결론

> **공공데이터 단독으로는 특정 지역 단위 서비스에 의존 불가.** 지역별 등록 편차가 너무 크다.

> **OSM이 현재 한국에서 "도보 가능한 모든 길" 수준의 커버리지를 제공하는 유일한 단일 소스**다. 라이선스는 ODbL(Open Database License)로 출처 표시만 지키면 무료.

이 결론이 새 POC의 전제가 됐다.

### 3-4. legacy/에 무엇이 남아 있고 왜 남겼는가

`legacy/` 폴더에는 다음이 **의도적으로** 보존돼 있다:

- `legacy/roads/services/api_client.py` — 공공데이터 포털의 레거시 TLS 호환 어댑터(`LegacyTLSAdapter`). Python 3.11의 강화된 TLS가 구버전 서버와 호환 안 되는 문제의 해결 코드.
- `legacy/roads/services/haversine.py` — 두 좌표 간 거리 계산.
- `legacy/roads/services/overpass_client.py` — Overpass API 호출 원형.
- `legacy/roads/views.py` 내 safemap WMS 프록시 엔드포인트.
- `legacy/map-poc-worklog.md` — 레거시 POC 전체 로그(API 이슈, SSL 문제, WMS 프록시 설계 등).

**삭제하지 않은 이유:** 러닝 검증(§6)에서 횡단보도 데이터나 Haversine 기반 근접 판별이 다시 필요해질 가능성이 있고, 공공 데이터 API 호출의 TLS 우회 코드는 차후 보완 데이터 도입 시 재사용 가치가 있다. **복원 비용을 줄이기 위해 cherry-pick 가능한 형태로 격리**했다.

---

## 4. 새 POC (OSM 기반) 기록

### 4-1. 목표와 성공 판정 기준

| 기준      | 목표                                             |
| ------- | ---------------------------------------------- |
| 데이터 규모  | 서울 전역 ≥ 150,000건 적재                            |
| 시각적 연속성 | 강남·서초·마포·용산 줌인 시 골목·간선·인도가 연속적으로 그려지고 이상 누락 없음 |
| UX (핵심) | 축소→확대·확대→축소 전환에서 **도로가 끊기거나 사라지지 않음**          |
| 성능      | 뷰포트 AJAX 응답 < 1초(로컬), 줌 변경 시 깜빡임 없음            |
| 저작권     | ODbL attribution이 화면에 상시 표시                    |

### 4-2. 데이터 소스 결정 — 왜 OSM인가, 왜 Overpass 직접 호출인가

#### 왜 OSM인가 (대안 비교)

- 공공데이터포털: §3에서 입증된 **커버리지 부재**. 탈락.
- 카카오/네이버 지도 API: 상업 API, 도로 원시 좌표 대량 추출이 이용약관상 불분명. POC 범위에서 리스크 큼.
- **OSM + Overpass**: 전 세계 커뮤니티 매핑, ODbL 라이선스로 비상업 목적 자유 사용, bbox 기반 대량 추출 API 제공. 한국 도심 기준 커버리지 양호. **채택.**

#### 왜 OSMnx 라이브러리가 아닌 Overpass 직접 호출인가

- OSMnx는 그래프 구조(노드·엣지)를 자동 추출하는 강력한 라이브러리지만, 이번 POC는 **그래프가 필요 없는 단순 시각화**다. OSMnx를 쓰면 의존성(geopandas, scipy 등)이 크게 늘고 적재 시간도 더 걸린다.
- Overpass에 POST 한 번으로 필요한 way만 JSON으로 받아 Python dict로 가공하는 것이 훨씬 가볍다. **추후 그래프가 필요해지는 시점에 OSMnx로 교체**하면 된다(§6-3).

### 4-3. 프로젝트 구조 스냅샷

```
map-data-poc/
├── legacy/                           # 레거시 POC 아카이브 (§3-4)
├── 공공데이터poc.md                   # 레거시 배경 문서
├── 작업계획new.md                     # 새 POC 작업 계획 (참고)
├── til.md                            # ← 이 문서
├── .env                              # KAKAO_API_KEY (gitignore)
├── .env.example                      # KAKAO_API_KEY=<your-kakao-javascript-api-key>
├── requirements.txt                  # django>=4.2, python-dotenv, requests
├── db.sqlite3                        # 적재 후 생성
├── manage.py
├── map_poc/                          # Django 프로젝트
│   ├── settings.py
│   └── urls.py
└── walkable/                         # 앱 이름 = 스코프 (기존 roads와 구분)
    ├── models.py                     # WalkableRoad 단일 모델
    ├── views.py                      # map_view, roads_api, stats_api
    ├── urls.py
    ├── categories.py                 # highway → category 매핑 (단일 소스)
    ├── services/
    │   └── overpass_client.py        # Overpass POST 호출 + 응답 파싱
    ├── management/commands/
    │   └── load_osm_seoul.py         # 적재 커맨드
    ├── sql/
    │   └── ddl.sql                   # 참고용 DDL
    ├── migrations/
    └── templates/walkable/
        └── map.html                  # 지도 페이지
```

### 4-4. DB 설계 핵심 결정

`walkable_road` 단일 테이블. 정규화하지 않았다.

```python
class WalkableRoad(models.Model):
    osm_id = models.BigIntegerField(unique=True)
    highway_type = models.CharField(max_length=50)
    category = models.CharField(max_length=20, db_index=True)
    name = models.CharField(max_length=200, blank=True)
    min_lat = models.FloatField(db_index=True)
    max_lat = models.FloatField(db_index=True)
    min_lng = models.FloatField(db_index=True)
    max_lng = models.FloatField(db_index=True)
    geometry_json = models.TextField()

    class Meta:
        db_table = "walkable_road"
        indexes = [
            models.Index(fields=["min_lat", "max_lat"]),
            models.Index(fields=["min_lng", "max_lng"]),
        ]
```

파일: `walkable/models.py`, `walkable/sql/ddl.sql`.

#### 결정 1 — `osm_id`를 BIGINT UNIQUE로 자연키 취급

- **무엇:** OSM이 각 way에 부여하는 전역 고유 ID를 그대로 저장하고 `unique=True`.
- **왜:** 재적재할 때 `bulk_create(ignore_conflicts=True)`로 중복을 안전하게 처리할 수 있다. 더 중요한 건, 프론트의 **Polyline diff(§4-6 결정 2)**가 이 값을 키로 "이 도로를 이미 그렸는가"를 판별한다는 점. Django 자동 PK(`id`)는 재적재 시 번호가 바뀌어 diff의 의미가 없다.
- **대안:** 자동 PK만 사용 → 같은 도로의 ID가 재적재마다 달라짐 → 프론트 diff 불가. 탈락.

#### 결정 2 — `highway_type` + `category` 두 컬럼 공존

- **무엇:** `highway_type`은 OSM 원본 태그(footway, residential 등 16종), `category`는 UI용 분류 4종(pedestrian/alley/arterial/trail).
- **왜:** 프론트 토글·색상·통계 쿼리의 키는 `category`면 충분하다. 그러나 원본 태그를 같이 저장하면 **분류 기준이 바뀌어도 재적재 없이 DB에서 재분류**할 수 있다("footway만 따로 볼래" 같은 요구에 즉시 대응).
- **대안:** highway_type만 저장 → 쿼리에서 `WHERE highway_type IN (...)` 매번 필요, 매핑 로직이 views와 categories에 중복. 탈락.

#### 결정 3 — **중심점 대신 bbox 4필드 (이 POC의 핵심 결정)**

- **무엇:** 각 도로의 polyline을 감싸는 **최소 경계 사각형**의 네 모서리를 `min_lat/max_lat/min_lng/max_lng`로 저장.
- **왜:** 도로는 "점"이 아니라 "선"이다. 중심점 하나로 뷰포트 필터링을 하면 **도로 중심점이 뷰포트 밖이지만 도로 자체가 뷰포트를 가로지르는 경우 통째로 누락**된다. 사용자 체감으로는 "확대하니까 갑자기 길이 없어진" 현상. 레거시 POC의 가장 큰 UX 결함이 바로 이 문제였다.
- bbox 4필드를 쓰면 `max_lat >= s AND min_lat <= n AND max_lng >= w AND min_lng <= e` 겹침 조건으로 **어떤 부분이라도 뷰포트와 겹치면 반드시 포함**된다.
- **대안 비교:**
  - `center_lat/lng`: 위 문제. 탈락.
  - PostGIS `ST_Intersects`: 가장 정확하고 공간 인덱스(GiST)와 결합하면 빠르다. 그러나 PostgreSQL + PostGIS 설치 필요. 서울 20만 건 규모에는 오버스펙. **실서비스 이관 시 우선 고려**로 기록(§8-2).
  - SQLite R-tree 확장: Django ORM에서 다루기 불편. 현 규모에선 B-tree 인덱스로 충분.

#### 결정 4 — `geometry_json`을 TEXT로 저장

- **무엇:** `[[lat, lng], [lat, lng], ...]` 좌표 배열을 JSON 문자열로 직렬화.
- **왜:** SQLite에는 geometry 타입이 없다. 별도 파싱 없이 `json.loads()`로 꺼내 바로 카카오 `LatLng` 생성에 사용 가능.
- **대안:**
  - 좌표 정규화(별도 `road_point` 테이블): 매 조회에 JOIN, 서울 규모에서 수백만 행 조회 발생. 성능 역전. 탈락.
  - WKT `LINESTRING(...)`: 프론트에서 파싱 라이브러리 필요, JSON보다 복잡. 탈락.

#### 결정 5 — 인덱스 분리(`(min_lat, max_lat)` + `(min_lng, max_lng)` 2개)

- **왜:** bbox 겹침 쿼리는 위도·경도 두 축 범위 조건을 동시에 쓴다. 복합 인덱스 하나로 두 축을 묶으면 SQLite는 첫 컬럼 이후 범위 조건에서 인덱스 효율이 떨어진다. **두 개의 2열 인덱스**를 쓰면 쿼리 플래너가 선택적인 쪽을 먼저 쓰고 나머지로 필터링할 수 있다.
- 추가로 `category` 단일 인덱스(`db_index=True`)는 카테고리 필터 쿼리용.

### 4-5. API 설계 핵심 결정

세 엔드포인트: `/` (지도 페이지), `/api/roads/` (뷰포트 조회), `/api/stats/` (전체 통계).
파일: `walkable/views.py`.

#### 결정 1 — bbox 겹침 쿼리

```python
qs = WalkableRoad.objects.filter(
    max_lat__gte=s, min_lat__lte=n,
    max_lng__gte=w, min_lng__lte=e,
)
```

§4-4 결정 3의 DB 구조를 쿼리 레벨에서 소비한다. 프론트가 `s, w, n, e`를 URL 파라미터로 넘기면 이 필터가 그대로 적용된다.

#### 결정 2 — 줌 레벨별 건수 상한 (브라우저 보호)

```python
def _cap_for_level(level: int) -> int:
    if level <= 4: return 8000   # 고확대: 넉넉히
    if level <= 6: return 5000
    return 3000                  # 축소: 보수적
```

카카오 지도 줌 레벨이 작을수록 고확대(좁은 뷰포트)다. 축소 상태에서 18만 건을 한꺼번에 내리면 브라우저가 먹힌다. 레벨별로 상한을 두고, 초과 시 `truncated: true` 플래그와 함께 일부만 반환한다.

#### 결정 3 — 줌 적응 자동 카테고리 축소

```python
def _auto_categories_for_level(level: int):
    if level >= 7: return ["arterial"]   # 축소 뷰: 간선만
    return None                          # 그 외: 전체 허용
```

- 사용자가 `categories` 쿼리 파라미터를 **지정하지 않고** 줌 레벨이 7 이상이면 자동으로 `arterial`만 반환. 서울 전역 축소 뷰에서 모든 골목길을 내리는 사고 방지.
- 사용자가 토글로 명시했으면 자동 축소를 **덮어쓰지 않는다** — 사용자 의도 존중.
- 이 자동 필터가 동작했음을 응답 `auto_filter: true`로 노출해 프론트가 "축소 뷰에서는 간선만 표시됩니다" 힌트를 띄운다.

### 4-6. 프론트엔드 UX 설계 핵심 결정

파일: `walkable/templates/walkable/map.html`. 카카오 Maps JS SDK + vanilla JS.

#### 결정 1 — `map.idle` 이벤트 + 200ms 디바운스

```js
kakao.maps.event.addListener(map, "idle", () => fetchRoads(true));
```

- `idle`은 사용자의 팬·줌이 **멈췄을 때** 한 번 발생한다. 매 프레임마다 발생하지 않아 네트워크 폭주를 막는다.
- 200ms 디바운스를 추가로 얹어 연속적 idle 상황(줌 한두 단계씩 빠르게 조작)에서 마지막 한 번만 호출되게 한다. **서버 부하와 깜빡임 동시 감소.**
- 카테고리 토글 체크박스 변경은 **디바운스 없이 즉시 재호출** — 의도된 명시적 조작이므로 반응성이 우선.

#### 결정 2 — Polyline diff (이 POC의 두 번째 핵심 결정)

프론트는 `osm_id → kakao.maps.Polyline` 매핑 하나를 유지한다. 매 응답마다:

1. 응답에 있고 기존에 없던 osm_id → **새 Polyline 생성**
2. 기존에 있었으나 응답에 없는 osm_id → `setMap(null)` 제거
3. **양쪽 모두에 있는 osm_id → 기존 Polyline 재사용** (재생성 없이 stroke 속성만 갱신)

**효과:** 확대·축소·패닝 시 "뷰포트에 계속 보이던 도로"는 DOM 레벨에서 유지된다. 사용자 눈에는 도로가 사라졌다 다시 나타나는 깜빡임이 없다.

#### 결정 3 — 줌 레벨별 stroke 차등

```js
function strokeFor(level) {
  if (level <= 3) return { weight: 4.0, opacity: 0.95 };  // 고확대: 굵고 진하게
  if (level <= 5) return { weight: 3.0, opacity: 0.85 };
  if (level <= 6) return { weight: 2.5, opacity: 0.75 };
  if (level <= 8) return { weight: 2.0, opacity: 0.7  };
  return             { weight: 1.5, opacity: 0.6  };
}
```

축소 상태에서 굵은 선이 겹치면 시각적 노이즈가 크다. 레벨에 따라 굵기·투명도를 조절해 **시각 계층**을 만든다. Polyline 재사용 시에도 `setOptions`로 stroke만 갱신.

#### 결정 4 — AbortController로 stale 응답 방어

```js
if (activeAbort) activeAbort.abort();
activeAbort = new AbortController();
const resp = await fetch(url, { signal: activeAbort.signal });
```

사용자가 A→B→C로 빠르게 팬하면, A·B에 대한 응답이 C 요청 이후 도착할 수 있다. 그러면 **C 뷰포트 위에 A·B 데이터가 그려지는 버그**가 생긴다. 직전 요청을 `abort()`로 끊어 stale 응답을 배제한다.

#### 결정 5 — ODbL attribution 상시 표시

범례 박스 하단에 `© OpenStreetMap contributors (ODbL)` + `https://www.openstreetmap.org/copyright` 링크를 고정. 카카오 기본 copyright와 **별도로** 표시해야 한다. OSM 라이선스상 "Produced Work"의 의무 사항.

### 4-7. 정량 결과

| 지표                       | 수치                                                           |
| ------------------------ | ------------------------------------------------------------ |
| 서울 전역 적재 건수              | **166,170** (레거시 시점 184k와 차이 — 아마도 `foot=no`/`access=private |
| 카테고리 분포 (적재 시 출력)        | `/api/stats/`에서 실시간 확인                                       |
| 적재 소요 시간                 | 약 2~~5분 (Overpass 응답 1~~3분 + DB 적재 ~1분)                      |
| `db.sqlite3` 크기          | 약 80~100MB 수준                                                |
| `/api/roads/` 응답 시간 (로컬) | 수백 ms ~ 1초 내 (뷰포트 크기·카테고리 수에 따라)                             |
| 브라우저 안정성                 | 줌 레벨 1~6에서 Polyline 수천 개 유지 시 크래시 없음                         |

---

## 5. 재현 가이드

완전히 새 세션에서 이 문서만으로 프로젝트를 다시 돌릴 수 있도록 작성.

### 5-1. 환경 요구사항

- Python 3.10+
- Windows/macOS/Linux 무관 (개발은 Windows 11 bash)
- Kakao Developers에 등록된 **JavaScript 키** 필요 (지도 SDK용)
- 카카오 API 키의 **Web 플랫폼 도메인**에 `http://127.0.0.1:8000` 등록 (5-3 함정 참조)

### 5-2. 실행 순서

```bash
# 1. 패키지 설치
pip install -r requirements.txt
# requirements.txt:
#   django>=4.2,<5.0
#   python-dotenv==1.0.1
#   requests==2.31.0

# 2. .env 작성
# .env.example 복사 후 키 입력
cp .env.example .env
# .env 내용:
#   KAKAO_API_KEY=<실제 카카오 JavaScript 앱 키>

# 3. DB 초기화
python manage.py migrate

# 4. 서울 전역 OSM 적재 (2~5분)
python manage.py load_osm_seoul --timeout 300
# 기대 출력 형태:
#   [1/3] Overpass 호출 (bbox: ..., timeout=300s) ...
#     → 166,170건 수신 (120.4s)
#     [pedestrian] XX,XXX건
#     [alley]      XX,XXX건
#     [arterial]   XX,XXX건
#     [trail]      XX,XXX건
#   [2/3] 기존 walkable_road 전량 삭제 ...
#   [3/3] 새 데이터 적재 ...
#   완료. walkable_road 총 166,170건.

# 5. 서버 실행
python manage.py runserver
# → http://127.0.0.1:8000/ 로 접속 (localhost 아님)
```

### 5-3. 알려진 함정

#### 함정 1 — `localhost:8000` 로 접속하면 지도가 안 뜬다

- **증상:** 브라우저 콘솔에 `Uncaught ReferenceError: kakao is not defined` 에러, 지도 영역이 빈 회색.
- **원인:** 카카오 개발자 콘솔에 등록된 Web 플랫폼 도메인이 `http://127.0.0.1:8000`이고 `http://localhost:8000`은 등록되지 않음. 카카오 SDK 로드 시 도메인 검증을 Referer로 수행하는데, `localhost`와 `127.0.0.1`은 **다른 도메인으로 취급**된다. 결과: SDK 스크립트가 HTTP 401 + JSON 에러로 응답 → `kakao` 전역 변수가 정의되지 않음 → 모든 이후 코드가 ReferenceError.
- **해결:** 브라우저에 **반드시 `http://127.0.0.1:8000/`**로 접속.
- **근본적 대안:** Kakao Developers → 내 애플리케이션 → 플랫폼 → Web → 사이트 도메인에 `http://localhost:8000`도 추가하면 둘 다 동작.

#### 함정 2 — Overpass API 406 Not Acceptable

- **원인:** User-Agent 헤더 누락.
- **해결:** `walkable/services/overpass_client.py`의 `_HEADERS`에 이미 `map-data-poc/2.0 (SSAFY educational project)` 지정돼 있음. 수정하지 말 것.

#### 함정 3 — Overpass 공용 인스턴스 사용 매너

- 호출은 적재 시 1회만. 잦은 재시도·짧은 timeout·헤더 없는 호출은 **IP 차단 위험**.
- 서비스 전환 시에는 **자체 Overpass 서버** 또는 OSM 지도 덤프(`.osm.pbf`)를 내려받아 OSMnx로 처리하는 구조로 이관해야 한다.

#### 함정 4 — 재적재 시 DB 잠금

- `load_osm_seoul`은 `WalkableRoad.objects.all().delete()`를 트랜잭션으로 실행한다. 서버가 돌고 있고 브라우저가 `/api/roads/`를 호출 중이면 SQLite 쓰기 잠금과 충돌할 수 있다. **재적재 전에 `runserver`를 끄거나 브라우저 탭을 닫는다.**

---

## 6. POC 이후 설계 대화 요약 (확장 기획)

POC 완료 후 "이 데이터를 실제 서비스에서 어떻게 쓸 것인가"에 대해 설계 논의를 진행했다. **구현은 하지 않았다** — 이 섹션은 기록용.

### 6-1. 세 가지 검증 시나리오

| 검증      | 입력              | 핵심 연산                                                       | 출력          | 현재 POC로 가능?             |
| ------- | --------------- | ----------------------------------------------------------- | ----------- | ----------------------- |
| ① 경로 생성 | 사용자 클릭/드로잉      | snap-to-road + (일반 러닝은 최단경로, 드로잉 런은 shape-to-graph fitting) | 도로 시퀀스 + 거리 | ❌ 그래프 구조 없음             |
| ② 경로 추종 | 저장 경로 + 실시간 GPS | map matching 후 원본 경로와 edge 시퀀스 비교                           | 이탈 구간       | ❌ 그래프·공간연산 없음           |
| ③ 자율 러닝 | GPS trace만      | map matching → walkable/forbidden 판정                        | 위반 구간       | ❌ 금지 도로 데이터 없음 + 그래프 없음 |

### 6-2. 드로잉 런 — 일반 러닝과 다른 요구

사용자가 GPS 궤적으로 **그림(동물, 글자 등)을 그리는** 경험. "종로 강아지 런"이 대표 사례.

|         | 일반 러닝 경로        | 드로잉 런                                      |
| ------- | --------------- | ------------------------------------------ |
| 평가 기준   | 거리·시간·고도        | 원본 그림과의 **형상 유사도**                         |
| 알고리즘    | 최단경로 (Dijkstra) | **map matching 계열** (입력만 GPS→사용자 드로잉으로 치환) |
| "좋은 경로" | 짧고 연속적          | 원본 곡선에서 최소한으로 이탈                           |

**핵심 통찰:** 드로잉 런의 "드로잉을 도로망에 투영" 문제는 자율 러닝의 "GPS를 도로망에 매칭" 문제와 **같은 알고리즘**(map matching)을 사용할 수 있다. 엔진 하나로 두 기능을 커버할 수 있다 → 투자 효율 좋음.

### 6-3. 그래프·공간 DB로의 이관 필요성

§6-1의 세 검증을 구현하려면 현재 단일 테이블로는 부족하다. 필요한 구조:

| 테이블              | 역할                                       | 현재 상태                     |
| ---------------- | ---------------------------------------- | ------------------------- |
| `osm_node`       | 교차점·way 끝점 (노드 좌표)                       | **없음**                    |
| `walkable_edge`  | 도로 세그먼트 (노드 쌍 + geometry + 길이)           | **없음** — 현재는 way 전체가 단일 행 |
| `forbidden_edge` | 명시적 비보행 도로 (motorway 등)                  | **없음** — 현재는 아예 저장 안 함    |
| `user_route`     | 사용자가 만든 경로 (intent + executable 두 지오메트리) | **없음**                    |
| `run_session`    | 러닝 기록 + GPS trace + map matching 결과      | **없음**                    |

엔진 선택지(논의만 하고 결정 안 함):

- **pgRouting** (PostgreSQL extension): SQL로 `pgr_dijkstra`, 자체 HMM 구현 필요
- **OSRM** (외부 서버): `/route`, `/match` REST API. Uber/Strava 수준의 map matching 품질
- **NetworkX + OSMnx** (Python in-memory): 개발 속도 빠름, 수평 확장 어려움

### 6-4. POC와 실개발 경계 — 왜 여기서 멈췄는가

드로잉 런·러닝 검증을 **지금 만들지 않은 판단 근거**:

- POC의 정의는 "**핵심 가설의 최소 실험**". 이번 POC의 가설은 "서울 전역 도보 가능 길 데이터 확보 가능 여부"였고, 이 가설은 검증됐다.
- 드로잉 런 전체 구현(드로잉 UI + 투영 + 저장 + 검증 + 공유)은 수 주~수 개월 단위 작업이고, 이는 **POC가 아니라 제품 개발**이다.
- 다만 **드로잉 런의 핵심 리스크**(서울 도로망 밀도가 형상 재현에 충분한가?)는 별도 미니 실험(`fit_drawing.py` 1~2일)으로 분리 가능. 이는 **다음 스텝의 후보**.

이 "POC와 제품 개발의 경계 구분" 자체가 엔지니어링 판단 역량으로 포트폴리오에서 설명할 소재가 된다.

---

## 7. 면접·포트폴리오 Q&A

면접관이 물어볼 가능성이 높은 질문과, 이 프로젝트 맥락에서 답할 수 있는 내용.

### Q1. 왜 공공데이터를 포기하고 OSM으로 전환했나요?

> 레거시 POC에서 강남구를 기준으로 실측해본 결과, 공공데이터포털의 **횡단보도 데이터는 강남구에 0건**이었고 **보행자전용도로는 2건(개포동만)**이었습니다. 반면 OSM은 같은 서울 전역에서 18만 건 수준의 커버리지로 골목과 계단까지 포함했습니다. 지역별 편차가 큰 공공데이터만으로는 도시 단위 서비스 신뢰성을 확보하기 어렵다고 판단했고, OSM의 ODbL 라이선스는 출처 표시만 지키면 사용 가능해 경제적 부담도 없었습니다.

### Q2. 지도 확대 시 도로가 끊기는 문제는 어떻게 해결했나요?

> 레거시 구조는 각 도로의 **중심점 좌표**로 뷰포트 필터링을 했는데, 한강 자전거도로처럼 긴 도로는 중심점이 화면 밖에 있으면 도로 전체가 누락됐습니다. 새 구조에서는 **도로의 bbox(최소 경계 사각형)**를 `min_lat, max_lat, min_lng, max_lng` 네 컬럼으로 저장하고, `max_lat >= s AND min_lat <= n AND max_lng >= w AND min_lng <= e` 겹침 조건으로 쿼리합니다. 도로의 **어떤 부분이라도 뷰포트와 겹치면 반드시 포함**되므로 확대·축소 어느 상황에서도 끊김이 발생하지 않습니다.

### Q3. 카카오 지도에 18만 건 폴리라인을 어떻게 브라우저 부담 없이 렌더링했나요?

> 세 가지 층을 같이 썼습니다. 첫째, **뷰포트 bbox 기반 AJAX 로딩**으로 화면에 보이는 것만 서버에서 내립니다. 둘째, **줌 레벨별 건수 상한과 자동 카테고리 축소** — 축소 상태(level≥7)에서 categories를 지정하지 않으면 간선만 내려 브라우저 보호. 셋째, **Polyline diff 렌더링** — osm_id 키 맵을 유지해서 팬·줌 시 공통 도로는 재사용하고 새 도로만 생성, 없어진 도로만 제거합니다. 결과적으로 줌 전환 시 깜빡임 없는 UX를 확보했습니다.

### Q4. 왜 SQLite로도 성능이 충분했나요? 실서비스는 어떻게 가실 건가요?

> SQLite에는 공간 인덱스(R-tree, GiST)가 없지만, **bbox 두 축에 대한 B-tree 인덱스를 2개**(`(min_lat, max_lat)`, `(min_lng, max_lng)`) 만들어 범위 필터 성능을 확보했습니다. 서울 20만 건 규모에서 뷰포트 쿼리가 수백 ms~1초 내로 응답했습니다. 다만 이건 POC 한정 판단이고, 실서비스로 가면 **PostgreSQL + PostGIS**로 이관해 `ST_Intersects` + GiST 인덱스를 쓰는 것이 정석입니다. 데이터가 10배 커지거나 map matching 같은 공간 연산이 추가되는 순간 SQLite는 한계를 맞습니다.

### Q5. POC의 범위는 어떻게 정하셨나요?

> 최종 서비스는 러닝 경로 생성·추종 검증·자율 러닝 검증·드로잉 런까지 포함됩니다. 그러나 이 모든 기능의 공통 전제는 **"도보 가능한 길 데이터가 서울 전역에 충분히 확보되는가"**입니다. 이 전제가 깨지면 나머지 기능은 무의미해지므로, POC는 이 단 하나의 가설만 검증했습니다. 드로잉 런 구현 자체는 수 주~수 개월 단위 제품 개발이라 POC의 정의에서 벗어납니다. 다만 드로잉 런의 **가장 불확실한 리스크**("서울 도로망 밀도가 그림 재현에 충분한가")는 수일짜리 미니 실험으로 분리 가능하다고 봤습니다.

### Q6. 실서비스로 이관한다면 무엇부터 바꾸시겠나요?

> 세 가지를 우선순위로 꼽습니다. 첫째, **DB를 PostGIS로 이관**해 공간 인덱스와 `ST_Intersects` `ST_DWithin` 같은 공간 연산을 확보합니다. 둘째, **그래프 구조를 도입** — 현재는 way 단위 단일 테이블이지만, 노드(osm_node)와 엣지(walkable_edge)로 정규화해야 경로 탐색과 map matching이 가능해집니다. OSMnx 라이브러리를 쓰면 `ox.graph_from_place` 한 줄로 추출됩니다. 셋째, **금지 도로(forbidden_edge) 테이블 추가** — 자율 러닝 검증에서 "도로가 아예 없는 공간"과 "명시적으로 금지된 도로"를 구분해야 false positive를 줄일 수 있습니다.

### Q7. 드로잉 런과 일반 경로 검증은 기술적으로 뭐가 다른가요?

> 일반 경로는 최단경로 문제(Dijkstra 계열)지만, 드로잉 런은 **형상 재현 문제**입니다. 사용자가 그린 자유 곡선을 도로망 위에 가장 닮게 투영해야 합니다. 이건 사실 **map matching의 입력을 GPS trace에서 사용자 드로잉으로 치환**한 문제로 환원됩니다. 그래서 드로잉 런과 자율 러닝 검증이 같은 알고리즘 스택(예: OSRM `/match` 또는 HMM)을 공유할 수 있습니다. 엔진 하나를 잘 만들어두면 두 기능을 커버할 수 있어 투자 효율이 좋습니다.

### Q8. GPS 끊김(터널·지하)은 어떻게 처리할 계획인가요?

> 아직 구현 전이지만 제품 정책 측면에서 먼저 결정해야 한다고 봅니다. 선택지는 세 가지입니다. (1) 끊긴 구간을 판정 실패로 처리, (2) 직전 매칭 edge로 선형 보간, (3) 검증 면책 구간으로 분류. 일반적으로 (3)을 기본으로 두고, 일정 시간 이상 끊기면 사용자에게 "이 구간은 검증 제외됩니다" 안내를 주는 방식이 현업 러닝 앱에서 자주 쓰입니다. 이건 **알고리즘 문제가 아니라 제품 UX 정책 결정**이라는 점이 중요합니다.

---

## 8. 범위 밖 — 오늘 의도적으로 하지 않은 것

면접 시 "왜 X를 안 했느냐"는 질문이 나오면 이 목록으로 답한다.

1. **OSMnx 도입** — 그래프 필요해지는 시점에 도입 예정. 지금은 의존성 최소화.
2. **PostGIS 이관** — 현 규모(20만 건)에서는 SQLite로 충분. 규모 성장 또는 공간 연산 필요 시 이관.
3. **드로잉 UI / 경로 저장 / 러닝 검증 / 사용자 인증** — 모두 POC 범위 밖 제품 기능.
4. **OSM 자동 갱신 크론** — POC는 스냅샷 데이터만 필요.
5. **벡터 타일(MVT) 변환** — Polyline AJAX 방식이 아직 충분. 데이터 10배 커지면 고려.
6. **서울 외 지역 확장** — Nominatim 기반 `--place` 인자 미구현. 서울 전용.
7. **Git 저장소 초기화** — POC 디렉토리. 추후 실 프로젝트로 분리 시 초기화 예정.
8. **테스트 코드** — POC 범위 밖. 설계 결정은 문서(til.md)와 코드 자체로 검증.

---

## 9. 다음 세션에서 이어가려면

### 9-1. 프로젝트를 다시 열었을 때

```bash
cd C:\Users\SSAFY\Desktop\map-data-poc
# 환경이 새로 세팅된 경우
pip install -r requirements.txt
# 이미 DB 있으면 바로
python manage.py runserver
# 브라우저: http://127.0.0.1:8000/
```

데이터가 오래됐다 싶으면 재적재:

```bash
python manage.py load_osm_seoul --timeout 300
```

### 9-2. 다음에 시도할 수 있는 미니 실험 3개

**실험 A — 드로잉 런 shape fitting 미니 실험 (1~2일)**

- 하드코딩된 드로잉 좌표 3개(하트, 별, 원) 준비
- `leuvenmapmatching` 파이썬 라이브러리 붙여서 강남·여의도·한강공원에 각각 투영
- intent vs executable을 같은 지도에 겹쳐 표시 + Frechet distance 계산
- 목적: "서울 도로망이 드로잉 런 형상 재현에 충분한가"의 정량 답.

**실험 B — 그래프 테이블 확장 (2~3일)**

- OSMnx로 서울 walk 그래프 추출 → `osm_node`, `walkable_edge` 테이블 적재
- 카카오 지도 클릭 2회로 A→B 최단 경로 POC (`networkx.shortest_path`)
- 현재 `walkable_road`는 유지하되, 병렬로 그래프 구조 적재해 마이그레이션 가능성 검증.

**실험 C — forbidden_edge 적재 (반나절)**

- Overpass에서 `motorway`, `motorway_link`, `trunk`, `trunk_link`를 추가 쿼리 → `forbidden_edge` 테이블 적재
- `/api/forbidden/` 엔드포인트 추가해 지도에 빨간 선으로 표시 → 자율 러닝 검증의 판정 기반 준비.

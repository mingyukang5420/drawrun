# OSM 데이터 적재 가이드

이지러닝 서비스의 보행 경로(`osm_ways`)와 횡단보도(`osm_crossings`) 데이터를 PostgreSQL/PostGIS에 적재합니다.
고도 데이터(`elevation_nodes`)를 포함하며, 코스 난이도 자동 산정에 사용됩니다.

---

## 디렉토리 구조

```
data/osm-loader/
├── loader/
│   ├── config.py              .env 기반 DB 접속 설정
│   ├── overpass_client.py     Overpass API 호출 (지역별 보행 경로 수집)
│   ├── parser.py              Overpass 응답 파싱
│   ├── elevation_client.py    Open Elevation API 호출 + 고도 계산
│   ├── db.py                  DB INSERT/UPDATE
│   ├── fetch.py               Overpass + 고도 API → CSV 저장 (담당자 1회성)
│   └── load.py                CSV → DB INSERT (로컬 파일 우선, 없으면 Google Drive)
├── sql/
│   ├── 01_extensions.sql      PostGIS 확장
│   ├── 02_schema.sql          테이블 스키마
│   └── 03_verify.sql          적재 결과 검증 쿼리
├── data/                      CSV 출력 위치 (git 제외)
│   ├── osm_ways.csv
│   └── osm_crossings.csv
└── requirements.txt
```

---

## 사전 준비

```bash
pip install -r requirements.txt
```

`.env` 파일을 `data/osm-loader/` 아래에 생성합니다.

```dotenv
# DB 접속 (전원 필수)
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=running
POSTGRES_USER=root
POSTGRES_PASSWORD=ssafy1234!

# Google Drive 공유 링크 (로컬 CSV 없을 때만 필요)
# 링크 형식: https://drive.google.com/uc?id={file_id}
GDRIVE_WAYS_URL=
GDRIVE_CROSSINGS_URL=
```

> `fetch.py`는 `.env` 없이 실행 가능합니다.

---

## 1. 데이터 담당자 — CSV 생성 (1회성)

Overpass API와 Open Elevation API를 호출해 CSV를 생성합니다. **약 1~2시간** 소요됩니다.
내부적으로 0.0 고도 노드를 자동 재요청합니다.

#### 적재 대상 지역 변경

`loader/fetch.py` 상단의 `DISTRICTS` 리스트로 관리합니다.

```python
DISTRICTS = [
    "마포구",
    "강남구",
]
```

#### 실행

```bash
# 1. 스키마 적용 (DB가 새로 구성된 경우)
docker exec -i localPostgis psql -U root -d running < sql/01_extensions.sql
docker exec -i localPostgis psql -U root -d running < sql/02_schema.sql

# osm_ways 테이블이 이미 있는 경우 고도 컬럼만 추가
docker exec -it localPostgis psql -U root -d running -c "
ALTER TABLE osm_ways
  ADD COLUMN IF NOT EXISTS elevation_nodes   JSONB,
  ADD COLUMN IF NOT EXISTS elevation_gain    FLOAT8,
  ADD COLUMN IF NOT EXISTS avg_uphill_grade  FLOAT8;
"

# 2. CSV 생성 (.env 불필요)
python -m loader.fetch
#    → data/osm_ways.csv, data/osm_crossings.csv 생성

# 3. CSV로 바로 DB 적재 (로컬 파일 자동 감지)
python -m loader.load

# 4. (선택) 팀원 공유용 — Google Drive에 CSV 업로드 후 GDRIVE URL 공유
```

---

## 2. 팀원 — DB 적재

팀원 초기 세팅, 서버 배포, Docker volume 초기화 시 모두 동일한 절차입니다.

### Google Drive URL이 있는 경우 (일반)

담당자에게 받은 URL을 `.env`의 `GDRIVE_WAYS_URL`, `GDRIVE_CROSSINGS_URL`에 설정합니다.

```bash
# 1. 스키마 적용
docker exec -i localPostgis psql -U root -d running < sql/01_extensions.sql
docker exec -i localPostgis psql -U root -d running < sql/02_schema.sql

# osm_ways 테이블이 이미 있는 경우 고도 컬럼만 추가
docker exec -it localPostgis psql -U root -d running -c "
ALTER TABLE osm_ways
  ADD COLUMN IF NOT EXISTS elevation_nodes   JSONB,
  ADD COLUMN IF NOT EXISTS elevation_gain    FLOAT8,
  ADD COLUMN IF NOT EXISTS avg_uphill_grade  FLOAT8;
"

# 2. DB 적재 (Google Drive에서 자동 다운로드)
python -m loader.load

# 3. 적재 결과 확인
docker exec -i localPostgis psql -U root -d running < sql/03_verify.sql
```

### Google Drive URL이 없는 경우

담당자에게 URL을 요청하거나, 직접 `fetch.py`를 실행합니다.

```bash
# 1. 스키마 적용 (위와 동일)

# 2. CSV 생성 (.env 불필요, 약 1~2시간 소요)
python -m loader.fetch

# 3. DB 적재 (로컬 CSV 자동 감지)
python -m loader.load

# 4. (선택) CSV를 Google Drive에 업로드 후 팀원에게 공유
```

---

## 주의사항

- `data/` 폴더의 CSV 파일은 `.gitignore`로 추적 제외되어 있습니다.
- `load.py`는 여러 번 실행해도 안전합니다. 고도 데이터가 이미 정상인 row는 UPDATE 대상에서 제외됩니다.
- 한강변 등 실제 고도 0m 지점은 0.0이 유지되며 정상입니다.
- 고도 데이터는 코스 난이도 자동 산정(BEGINNER / EASY / NORMAL / HARD)에 사용됩니다.

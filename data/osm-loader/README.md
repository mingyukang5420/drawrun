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
├── run_loader.sh              DB 적재 실행 스크립트 (팀원용)
└── requirements.txt
```

---

## 사전 준비

**필수: Docker 실행 중이어야 합니다.**

`.env.example`을 복사해 `.env`를 생성하고 값을 채웁니다.

```bash
cp .env.example .env
```

항목 설명은 `.env.example` 주석을 참고하세요.

> `fetch.py`는 `.env` 없이 실행 가능합니다.

---

## 1. 데이터 담당자 — CSV 생성 (1회성)

Overpass API와 Open Elevation API를 호출해 CSV를 생성합니다. **약 1~2시간** 소요됩니다.
내부적으로 0.0 고도 노드를 자동 재요청합니다.

> Python 환경 필요: `pip install -r requirements.txt`

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

# 2. CSV 생성 (.env 불필요, 약 1~2시간 소요)
python -m loader.fetch
#    → data/osm_ways.csv, data/osm_crossings.csv 생성

# 3. DB 적재
bash run_loader.sh

# 4. 팀원 공유용 — Google Drive에 CSV 업로드 후 GDRIVE URL 공유
```

---

## 2. 팀원 — DB 적재

팀원 초기 세팅, 서버 배포, Docker volume 초기화 시 모두 동일한 절차입니다.
**Python 설치 불필요, Docker만 있으면 됩니다.**

#### 스키마 적용 (최초 1회 또는 volume 초기화 시)

```bash
docker exec -i localPostgis psql -U root -d running < sql/01_extensions.sql
docker exec -i localPostgis psql -U root -d running < sql/02_schema.sql
```

### Google Drive URL이 있는 경우 (일반)

담당자에게 받은 URL을 `.env`의 `GDRIVE_WAYS_URL`, `GDRIVE_CROSSINGS_URL`에 설정합니다.

```bash
bash run_loader.sh
```

스크립트가 Google Drive에서 CSV를 자동으로 다운로드하여 DB에 적재합니다.

### Google Drive URL이 없는 경우

직접 `fetch.py`를 실행하거나 담당자에게 URL을 요청합니다.

```bash
# Python 환경 필요: pip install -r requirements.txt
python -m loader.fetch      # 약 1~2시간 소요, data/ 에 CSV 생성

bash run_loader.sh          # 로컬 CSV 자동 감지하여 적재
```

#### 적재 결과 확인

```bash
docker exec -i localPostgis psql -U root -d running < sql/03_verify.sql
```

---

## run_loader.sh 동작 방식

```
.env 로드
  ↓
POSTGRES_HOST가 컨테이너 이름인 경우 → 해당 Docker 네트워크 자동 감지
POSTGRES_HOST가 localhost인 경우     → --network host (EC2 포함 모든 환경 호환)
  ↓
python:3.11-slim 컨테이너 실행
  ↓
pip install → python -m loader.load
  ↓
로컬 CSV 있으면 사용, 없으면 GDRIVE_WAYS_URL / GDRIVE_CROSSINGS_URL 에서 다운로드
```

로컬 CSV 우선 순위: `data/osm_ways.csv`, `data/osm_crossings.csv` 존재 시 Google Drive URL 불필요.

---

## 주의사항

- `data/` 폴더의 CSV 파일은 `.gitignore`로 추적 제외되어 있습니다.
- `run_loader.sh`는 여러 번 실행해도 안전합니다. 고도 데이터가 이미 정상인 row는 UPDATE 대상에서 제외됩니다.
- 한강변 등 실제 고도 0m 지점은 0.0이 유지되며 정상입니다.
- 고도 데이터는 코스 난이도 자동 산정(BEGINNER / EASY / NORMAL / HARD)에 사용됩니다.
- Open Elevation API는 월 1,000건 제한이 있습니다. 추가 지역 확장 시 자체 호스팅을 고려하세요.

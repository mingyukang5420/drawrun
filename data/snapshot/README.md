# dev DB 시연용 snapshot

dev(EC2) DB 의 도메인 데이터를 **시연 초기 상태**로 보존/복원하는 스크립트.

테스트 중 쌓인 쓰레기 데이터를 `restore.sh` 한 번으로 원래 상태로 되돌린다.

## 동작 범위

| 대상 | 처리 |
|---|---|
| `members`, `tracks`, `records`, `courses`, `course_drafts`, `course_district`, `course_bookmark`, `challenges`, `member_record_stats` | dump / restore |
| `orders` (entity 없는 잔재 테이블) | restore 시 TRUNCATE 만 |
| `districts`, `osm_ways`, `osm_ways_split`, `osm_crossings` | **건드리지 않음** (OSM-loader 담당) |
| Redis, 업로드 파일 (`/home/ubuntu/uploads/...`) | **건드리지 않음** |

## 사전 준비

1. `cp .env.example .env` 후 `DEV_DB_PASSWORD` 채우기 (`data/mock-loader/.env` 에서 복사 가능).
2. `docker-compose up -d` 로 로컬 PostGIS 컨테이너(`localPostgis`) 가 떠 있어야 함 — `pg_dump`/`psql` 실행 환경으로 재사용.

## 사용법

### 1) 최초 snapshot 생성 (1회)

```bash
bash dump.sh
```

`snapshot.sql` 이 만들어지고 git 으로 커밋된다. 기존 파일이 있으면 안전을 위해 거부 — `update.sh` 사용.

### 2) snapshot 갱신

dev DB 를 직접 조작해서 시연 기준 상태를 바꾼 뒤:

```bash
bash update.sh
```

- 기존 `snapshot.sql` → `snapshot.sql.bak` 자동 백업
- 새 `snapshot.sql` 생성
- 테이블별 INSERT 문 변화량 출력
- 잘못 갱신했으면 `mv snapshot.sql.bak snapshot.sql` 로 rollback

### 3) dev DB 를 snapshot 상태로 복원

```bash
bash restore.sh              # 확인 프롬프트 표시
bash restore.sh --dry-run    # 실제 변경 없이 현재 row count 만 확인
bash restore.sh --yes        # 확인 프롬프트 생략 (자동화용)
```

흐름:
1. 도메인 9개 + `orders` 를 `TRUNCATE ... RESTART IDENTITY CASCADE` (시퀀스 초기화 + FK 무시)
2. `snapshot.sql` 의 INSERT 들을 실행 (pg_dump 가 부모→자식 순으로 정렬)
3. 전체를 한 트랜잭션으로 감싸 실패 시 자동 롤백

## 기술 노트

- `pg_dump --data-only --column-inserts` — 스키마는 `ddl-auto: update` 에 맡기고 데이터만 떠온다. 컬럼명 포함 INSERT 라 컬럼 변경에도 비교적 안전.
- **PostGIS geometry** 는 pg_dump 가 EWKB hex 로 직렬화 → 그대로 INSERT 하면 복원됨. SRID 4326 정보도 함께 보존.
- **identity 시퀀스** 는 `RESTART IDENTITY` 로 1 부터 재시작. snapshot 의 INSERT 가 명시적으로 PK 값을 박아넣으므로, 복원 후 PostgreSQL 이 다음 sequence 값을 자동으로 따라잡는다 (`OVERRIDING SYSTEM VALUE` 동작).
- **트랜잭션 + `session_replication_role = replica`** — TRUNCATE CASCADE 이후라 FK 위반 가능성은 없지만, snapshot INSERT 순서에 만일을 대비한 안전 장치.

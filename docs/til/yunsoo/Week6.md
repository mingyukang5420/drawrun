## Week 6 (05.11 ~ 05.15)

## 목차
- [0511 Mon](#-0511--mon)
- [0512 Tue](#-0512--tue)
- [0513 Wed](#-0513--wed)
- [0514 Thu](#-0514--thu)
- [0515 Fri](#-0515--fri)

---

### 📘 0511 · Mon

#### 오늘 한 일 (What I did)
- 날씨 API 구현 완료 및 MR 제출 (위경도 → 구 조회 → Redis → WeatherResponse)
- DBeaver로 로컬 PostgreSQL 연결, 테스트 데이터 직접 삽입
- develop 브랜치 머지 및 conflict 해결 (District.java, DistrictRepository.java)

#### 배운 것 (What I learned)
- Spring Batch vs @Scheduled — 250개 구 날씨 데이터는 단순 반복 호출이라 @Scheduled로 충분, Batch는 오버엔지니어링
- DBeaver로 Docker PostgreSQL에 GUI 연결하면 터미널보다 훨씬 편하고 어떤 DB든 연동해서 쓸 수 있음
- PostGIS geometry 타입 쓰려면 `CREATE EXTENSION IF NOT EXISTS postgis;` 먼저 실행해야 함

#### 문제 & 해결 (Problem & Solution)
- **문제:** districts 테이블 데이터 없어서 API 500 에러
- **해결:** DBeaver로 테스트 데이터 직접 삽입
- **문제:** `application-local.yaml`에 API 키 하드코딩 되어있었음
- **해결:** 환경변수로 변경
- **문제:** `SPRING_PROFILES_ACTIVE=local` 미설정으로 DB 연결 실패
- **해결:** IntelliJ Active profiles에 `local` 추가

#### 인사이트 (Insight)
- 기술 선택은 더 좋은 것보다 지금 문제에 맞는 것이 중요 — 학습 환경에선 오버엔지니어링해도 티 안 나지만 현업에서는 괜히 복잡도 올리면 팀 전체 비용이 될 수 있음

#### 다음 할 것 (What's Next)
- MR 리뷰 반영
- districts 전체 데이터 osm-loader로 삽입 (아직 잘 모름)
- 프론트 팀원이랑 날씨 API 연동

---

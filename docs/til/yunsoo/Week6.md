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

### 📘 0512 · Tue

#### 오늘 한 일 (What I did)
- 502 에러 원인 분석 및 해결 방향 도출 (Jenkins ENV 미주입 → 백엔드 기동 실패)
- 날씨 API 코드 리뷰 피드백 전체 반영 및 MR 수정

#### 배운 것 (What I learned)
- 502 Bad Gateway는 Nginx 문제가 아니라 upstream(백엔드)이 안 떠있을 때 발생
- `@PostConstruct`는 메인 스레드에서 실행되어 외부 API 장애 시 앱 기동 지연 가능 → `@Async + @EventListener(ApplicationReadyEvent.class)`가 더 안전
- `ObjectMapper`를 `new`로 생성하면 Spring Boot Jackson 자동설정 상속 안 됨 → Bean 주입 써야 함
- Redis 역직렬화 시 직접 캐스팅하면 `LinkedHashMap` → `ClassCastException` 발생 가능 → `ObjectMapper.convertValue()` 사용

#### 문제 & 해결 (Problem & Solution)
- **문제:** 팀원 환경에서 502 에러, 스웨거/로그인 전부 불가
- **원인:** Jenkins에 `WEATHER_API_KEY` 미등록 → Spring Boot `@Value` 주입 실패 → 기동 전 프로세스 종료
- **해결:** Grafana Loki로 `APPLICATION FAILED TO START` 로그 확인 후 Jenkins Credentials에 키 등록

#### 인사이트 (Insight)
- 필수 환경변수 하나 없으면 서비스 전체가 뻗음, 로컬에선 잘 되다가 배포에서 터지는 대표적인 패턴

#### 다음 할 것 (What's Next)
- 남은 API 작업들 하기

---

### 📘 0513 · Wed

#### 오늘 한 일 (What I did)
- 챌린지 기능 추가 방향 팀 회의 (AI가 polygon 생성 → 사용자가 코스 따라 뛰기 → 유사도 기반 랭킹)

#### 배운 것 (What I learned)
- 

#### 문제 & 해결 (Problem & Solution)
- 

#### 인사이트 (Insight)
- 

#### 다음 할 것 (What's Next)
- 챌린지 기능 기반 구현 시작

---

### 📘 0514 · Thu

#### 오늘 한 일 (What I did)
- 챌린지 기능 기반 구현 (ERD 설계, `Challenge` 엔티티 및 DTO 작성, `records` 테이블 컬럼 추가)
- 로컬/EC2 DB 구조 확인 및 DBeaver에서 DDL 직접 실행 후 서버 기동 확인
- MR 올린 후 git 충돌 트러블슈팅 및 정리

#### 배운 것 (What I learned)
- `BigDecimal`은 소수점 정밀도가 중요한 값에 사용, `Double`/`Float`은 부동소수점 오차 발생 가능
- `git add .`은 충돌 해결 상황에서 위험 — 충돌난 파일만 `git add [파일경로]` 해야 함

#### 문제 & 해결 (Problem & Solution)
- **문제:** MR 후 conflict 발생, 충돌 해결하면서 `git add .` 했더니 FE 파일 21개가 내 MR changes에 잡힘
- **해결:** `git reset --hard`로 원하는 시점으로 돌아간 후 `git rebase develop`으로 깔끔하게 재정리

#### 인사이트 (Insight)
- merge는 머지 커밋이 남고 rebase는 내 커밋을 develop 위에 재배치해서 히스토리가 일직선
- 결과는 같지만 히스토리 모양이 다름

#### 다음 할 것 (What's Next)
- 백엔드 팀원들과 상의하고 챌린지 구현 작업 나누기

---
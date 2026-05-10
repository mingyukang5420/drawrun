## Week 5 (05.04 ~ 05.08)

## 목차
- [0504 Mon](#) (사유결석)
- [0505 Tue](#) (휴일)
- [0506 Wed](#-0504--wed)
- [0507 Thu](#-0504--thu)
- [0508 Fri](#-0504--fri)

---

### 📘 0506 · Wed

#### 오늘 한 일 (What I did)
- Grafana + Loki + Promtail 스택 `docker-compose.yml`에 추가
- Docker 로그 드라이버 설정 (json-file, max-size, max-file)
- `loki-config.yml`, `promtail-config.yml` 작성 (로그 보존 7일, 컨테이너 로그 수집)
- Nginx `/grafana` 리버스 프록시 추가
- Grafana Loki 데이터소스 프로비저닝 파일 작성 후 MR 올림
- Spring Boot 로컬 실행 확인 (PostgreSQL + Redis Docker), Swagger UI 접근 완료
- Flutter + Android Studio 환경 세팅 완료

#### 배운 것 (What I learned)
- Grafana / Loki / Promtail = 시각화 / 저장 / 수집 — 각각 역할이 명확히 분리됨
- 바인드 마운트(`EC2경로:컨테이너경로`)는 내가 경로 직접 지정, 네임드 볼륨은 Docker가 알아서 관리
- 프로비저닝 파일로 데이터소스 미리 정의해두면 컨테이너 뜰 때 자동 적용됨

#### 문제 & 해결 (Problem & Solution)
- **문제:** `be/.gradle/`, `be/build/` 등이 이미 git에 추적되고 있어서 `.gitignore`에 추가해도 무시가 안 되고 VSCode Source Control에 계속 표시됨
- **해결:** `git rm -r --cached be/.gradle be/build` 로 git 추적 목록에서 제거

#### 인사이트 (Insight)
-  로그 수집 스택도 결국 데이터 흐름 — 어디서 수집해서 어디에 저장하고 어디서 보여주는지 흐름만 잡으면 설정이 이해됨

#### 다음 할 것 (What's Next)
- MR 머지 후 EC2 반영 및 컨테이너 정상 기동 확인
- Grafana 브라우저 접속 + 각 컨테이너 로그 수집 확인

---

### 📘 0507 · Thu

#### 오늘 한 일 (What I did)
- Grafana + Loki + Promtail EC2 반영 및 정상 동작 확인
- Grafana 브라우저 접속, Loki 데이터소스 연결, backend 로그 수집 확인

#### 배운 것 (What I learned)
- `proxy_pass`에 경로를 쓰면 `location` 매칭 부분을 잘라내고 대체함 — 서비스마다 내부 경로에 맞게 다르게 써야 함
- `docker compose logs nginx -f` 로 실시간 로그 보면서 status code, 요청 경로로 디버깅 가능
- 브라우저 F12 → Network → Response Headers의 Location 헤더로 리다이렉트 목적지 확인 가능

#### 문제 & 해결 (Problem & Solution)
- **문제:** Grafana 접속 시 `ERR_TOO_MANY_REDIRECTS` 발생
- **원인:** Nginx는 `/grafana/` 잘라내고 `/`만 전달하는데, Grafana는 자기가 `/grafana/`에 있다고 알고 있어서 계속 `/grafana/`로 리다이렉트하는 무한루프
- **해결:** `proxy_pass http://grafana:3000/grafana/` 로 수정해서 Grafana가 기대하는 경로와 일치시킴

#### 인사이트 (Insight)
- Nginx 경로 설정은 "Nginx가 어떻게 자르고 붙이는지"랑 "서비스가 어떤 경로를 기대하는지" 두 개를 같이 봐야 함

#### 다음 할 것 (What's Next)
- 머지 전 코드 불필요하게 빌드 안되게 Jenkins Trigger 세팅
- 백엔드 개발 태스크 시작

---

### 📘 0508 · Fri

#### 오늘 한 일 (What I did)
- 프로젝트 백엔드 구조 파악 (Domain-driven Feature Slice, abstract DTO, static Converter 패턴)
- 날씨 기능 전체 플로우 확인 (region → districts DB → 위경도 → 기상청 격자 변환 → API → Redis)
- `District.java`에 `center_point` 필드 추가 (PostGIS Point, hibernate-spatial 매핑), `findBySidoAndGu()` 추가

#### 배운 것 (What I learned)
- 기상청 단기예보 API는 base_time이 하루 8개 고정 시각으로 제한됨 (5, 8, 11, ...)
- Spring Batch Job → Step → Scheduler 구조로 정해진 시각마다 전체 구 날씨 데이터를 Redis에 미리 채워두는 방식
- `redisTemplate`(문자열/JWT)과 `redisObjectTemplate`(객체/날씨)을 분리하는 이유

#### 문제 & 해결 (Problem & Solution)
- **문제:** Spring Boot에서 이미지 저장 시 EC2 `uploads/tracks` 경로에 저장 안 됨
- **현재 상태:** 미해결, 다음에 이어서 확인 예정

#### 인사이트 (Insight)
- TTL 기반 캐싱보다 Batch로 정해진 시각에 선제적으로 채워두는 게 기상청 API 특성상 더 맞는 설계

#### 다음 할 것 (What's Next)
- `SkyCondition` enum 및 `WeatherResponse.java` DTO 작성
- `WeatherApiClient.java` 작성 (기상청 API 호출)
- EC2 이미지 저장 경로 문제 해결

---

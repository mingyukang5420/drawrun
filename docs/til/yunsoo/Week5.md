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

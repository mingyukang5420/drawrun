## Week 4 (04.27 ~ 04.30)

## 목차
- [0427 Mon](#0427-mon) 사유결석
- [0428 Tue](#0428-tue)
- [0429 Wed](#0429-wed) 사유조퇴
- [0430 Thu](#0430-thu) 사유결석

---

### 📘 0428 · Tue

#### 오늘 한 일 (What I did)
- Jenkins Credentials 등록 (GitLab PAT, git clone 인증용, 배포용 .env Secret file)
- EC2 배포용 `.env` 작성 (컨테이너 이름으로 host 변경, prod 프로파일 설정)
- Jenkinsfile 작성 (env 준비 → Gradle 빌드 → Docker 배포 + Mattermost 알림)
- `infra/docker-compose.yml`에 postgres, redis, backend 서비스 추가
- Jenkins 파이프라인 SCM 방식으로 전환 (develop 브랜치 자동 트리거)
- UFW 5432, 6379 포트 개방

#### 배운 것 (What I learned)
- Git clone 인증엔 GitLab API token 타입이 안 되고 Username with password 타입을 써야 함
- Docker Compose 환경에서 컨테이너끼리 통신할 땐 `localhost` 대신 컨테이너 이름으로 접근해야 함
- Jenkins에 등록한 Secret file은 수정이 안 되고 삭제 후 재등록해야 함

#### 문제 & 해결 (Problem & Solution)
- **문제:** `docker compose down` 하면 jenkins, nginx까지 전부 내려감
- **해결:** `stop` + `rm` 조합으로 backend 컨테이너만 재시작하도록 Jenkinsfile 수정
- **문제:** `.env`에 비밀번호가 있어 GitLab에 올리면 안 됨
- **해결:** `.gitignore` 처리 후 Jenkins Credentials Secret file로만 관리

#### 인사이트 (Insight)
- 인프라 작업은 삽질이 곧 공부 — 트러블슈팅 하나하나가 다 개념으로 남음
- 로컬용이랑 배포용 compose 파일 분리해두니 환경별 관리가 훨씬 명확해짐

#### 다음 할 것 (What's Next)
- Docker 인프런 강의 수강
- Nginx 리버스 프록시 규칙 우선순위 공부
- 실제 백엔드 배포 파이프라인 동작 확인

---


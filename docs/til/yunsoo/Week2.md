## Week 2 (04.13 ~ 04.17)

## 목차
- [0413 Mon](#0413-mon)
- [0414 Tue](#0414-tue)
- [0415 Wed](#0415-wed)
- [0416 Thu](#0416-thu)
- [0417 Fri](#0417-fri)

---

### 📘 0413 · Mon

#### 오늘 한 일 (What I did)
- EyeTrax 로컬 설치 및 테스트
- GazeFollower 로컬 실행 및 실시간 시선 시각화 테스트
- 2024~2026 웹캠 eye tracking 기술 수준 조사 (Liner AI 활용)

#### 배운 것 (What I learned)
- EyeTrax는 사분면(왼/오/위/아래) 수준만 감지 가능 — 줄/단어 단위 특정 불가
- GazeFollower pip 버전 기준 최고 오차 0.92cm(≈34~37px), 단어 너비(40~80px)랑 비슷한 수준이라 단어 감지는 여전히 무리
- 줄 단위는 텍스트 크기/행간 키우면 조건부로 가능성 있음

#### 문제 & 해결 (Problem & Solution)
- 가상환경 충돌(skeleton-3 vs 시스템 Python 3.11) → 환경 분리
- mediapipe 호환 오류 → 0.10.18로 다운그레이드
- add_subscriber 콜백 시그니처 오류 (face_info, gaze_info 두 파라미터 필요) → 확인 후 수정

#### 인사이트 (Insight)
- 웹캠으로 어느 단어를 읽고 있는지 감지하는 건 현재 오픈소스로는 불가능한 수준
- Tobii 같은 전용 하드웨어는 단어 단위 정밀도 나오지만 수백만 원대라 MVP에 비현실적
- 캘리브레이션을 매번 해야 하는 UX 문제도 있음

#### 다음 할 것 (What's Next)
- eye tracking 없이 읽기 보조하는 연구 사례 조사
- Attention weight 기반 단어 강조 방향 구체화

---

### 📘 0414 · Tue

#### 오늘 한 일 (What I did)
- eye tracking 없이 읽기를 보조하는 학술 연구 조사
- 서비스 타겟 및 콘텐츠 소싱 전략 확정
- Transformer Attention 개념 정리 및 서비스 적용 방식 기획

#### 배운 것 (What I learned)
- Bionic Reading: 일반 독자에게 효과 없음 — 7개 독립 연구로 반박됨 (Readwise 2022 2074명, Snell 2024 등)
- RSVP(Spritz 등): 역행 시선 차단으로 400wpm 이상에서 이해도 급락
- Digital Reading Rulers (Niklaus et al., CHI 2023): 177명 실험, 일반인도 분당 29~36단어 향상, 이해도 손실 없음
- Constrained Highlighting (Joshi & Vogel, CHI 2024 Best Paper): 150단어 제한 하이라이팅이 이해도 19% 향상 — 적게 강조할수록 더 효과적
- 상용 e북(교보, 밀리의서재) DRM 제한으로 직접 연동 불가 → MVP는 사용자 업로드 PDF로 확정

#### 문제 & 해결 (Problem & Solution)
- [eye tracking으로 모르는 단어 감지]라는 전제가 무너짐 — fixation 시간만으로는 판별 불가
- eye tracking 없이 읽기 보조하는 방향으로 전환해서 생각해보기

#### 인사이트 (Insight)
- Bionic Reading 실패 이유가 명확함: 고정된 규칙 기반 강조, 개인화 없음 → Attention weight 기반 동적 강조가 차별점이 될 수 있음
- Constrained Highlighting이 우리 방향이랑 제일 직결되는 연구

#### 다음 할 것 (What's Next)
- Attention weight 시각화 프로토타입 테스트
- 텍스트 유형별(정보글 vs 서사) 적합성 검토

---

### 📘 0415 · Wed

#### 오늘 한 일 (What I did)
- Transformer Attention / Attention weight / Self-Attention 개념 정의 및 구분 정리
- 한국어 텍스트 샘플 3개(기술/과학/사회) 작성, ChatGPT/Claude 비교 테스트

#### 배운 것 (What I learned)
- Attention(개념) / Attention weight(수치화된 결과값 0~1) / Self-Attention(Transformer에서의 구현) 구분
- raw attention weight는 레이어×헤드 수만큼 수백 개 나옴 → 이걸 결합·임계값 처리하는 알고리즘이 서비스 차별점

#### 문제 & 해결 (Problem & Solution)
- 없음

#### 인사이트 (Insight)
- 정보글은 단일 Attention weight 시각화가 유효하지만 서사/소설은 독자마다 감정적 무게가 달라서 단일 점수가 오히려 왜곡될 수 있음
- 서사 텍스트에는 다축 시각화(감정 강도, 서사 전환점, 인물 관계 밀도) 개인 마다 달라서 attention weight 표시 기준이 애매할 수 있음

#### 다음 할 것 (What's Next)
- 서비스 기획안 구체화 및 기능 정의 문서 작성
- 기획안 기반 PPT 제작

---

### 📘 0416 · Thu

#### 오늘 한 일 (What I did)
- Reado 서비스 기획안 구체화 및 핵심 기능 정의
- 중간발표 PPT 제작

#### 배운 것 (What I learned)
- MVP 범위 확정: 사용자 업로드 PDF → Attention weight 기반 단어 강조 렌더링
- 서비스 차별점: generative AI(확률 기반)가 아닌 수학적 근거 있는 Attention weight 추출값 사용

#### 문제 & 해결 (Problem & Solution)
- 없음

#### 인사이트 (Insight)
- 근거로 먼저 깔고 → 우리 방식 제시

#### 다음 할 것 (What's Next)
- 이번 주 TIL 정리
- 팀과 eye tracking 방향 전환 결과 공유 및 다음 스프린트 방향 논의

---

### 📘 0417 · Fri

#### 오늘 한 일 (What I did)
- 서비스 중간발표 진행
- 팀원들과 기획안 공동 작성
- eye tracking 기능 방향성 관련 팀 회의
- 컨설턴트님과 기획방향 점검 미팅

#### 배운 것 (What I learned)
- 없음

#### 문제 & 해결 (Problem & Solution)
- eye tracking 기능을 실제 서비스에 넣는 것에 대한 현실적인 문제들이 회의 중 나옴
    - Java/웹 환경에서 구현 가능한지 불확실
    - 구현이 된다 해도 한국어 텍스트 읽기에 실제로 효과가 있는지 검증이 안 됨
    - 검증하려면 테스트 설계(기준, 텍스트 선정), 샘플 수집, 결과 해석까지 해야 하는데 이게 다 별도 작업
    - 결과가 60:40으로 나오면 어떻게 판단할지도 애매함
- eye tracking이 구현된다 해도 우리 서비스의 와우포인트가 될 만큼 임팩트가 있는지 의문
- 난독증이 없는 일반 독자 입장에서는 시선 따라 뭔가 움직이는 게 오히려 거슬릴 수 있음 (부산스럽고 방해되는 느낌)
- eye tracking 기반 실시간 보조는 난독증 사용자에게 효과적인데, 우리 타겟은 난독증이 아닌 문해력 낮은 일반 현대인 → 타겟과 기능이 안 맞음
- 결론 미정, 계속 논의 필요

#### 인사이트 (Insight)
- 일반 독자에게는 정적인 보조(ruler, 단어 강조)가 동적인 eye tracking보다 더 적합할 수 있음
- 아이디어 도출할때 너무 정직하게 하지말고 요리조리 틀어서 생각해보기

#### 다음 할 것 (What's Next)
- 기능 범위 재정의 후 기획안 업데이트
- 다음주 월요일까지 새로운 아이디어 생각해보기
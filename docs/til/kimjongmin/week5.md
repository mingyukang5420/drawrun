# 2026-05-04

- `equalsIgnoreCase`: 대소문자를 구별하지 않고 비교한다.

## Fetch Join

- 연관 엔티티를 JOIN해서 한 번의 쿼리로 같이 끌고 오는 명령
  
  ```java
  // JPQL
  SELECT m FROM Member m JOIN FETCH m.team
  ```

- 실행되는 쿼리

- ```sql
  SELECT m.*, t.*
  FROM member m
  INNER JOIN team t ON m.team_id = t.id
  ```
  
  - 멤버가 100명이어도 쿼리 1번으로 멤버와 팀 데이터를 한꺼번에 가져옴

- 일반 Join과는 어떤 차이가 있는가?

- ```java
  // 일반 JOIN
  SELECT m FROM Member m JOIN m.team
  
  // Fetch JOIN
  SELECT m FROM Member m JOIN FETCH m.team
  ```
  
  - 일반 Join은 **조건 필터링** 용도로만 쓰임. team 데이터를 가져오지 않음
    
    - 즉 SELECT 대상이 아닌 연관 엔티티는 영속성 컨텍스트에 올리지 않음
  
  - Fetch Join은 데이터까지 같이 로딩하여 영속성 컨텍스트에 올려놓음

- 그럼 EAGER과의 차이는?
  
  - ```sql
    -- EAGER 설정 시 JPA가 자동으로 날리는 쿼리 (최악의 경우)
    SELECT * FROM member;
    SELECT * FROM team WHERE id = 1;   -- member별로 개별 쿼리
    SELECT * FROM team WHERE id = 2;
    ...
    ```
  
  - EAGER는 즉시 로딩하는 전략이지 JON으로 한번에 데이터를 가져온다는 보장이 없음. JPA 구현체가 알아서 판단하는데 개별 쿼리를 날리게 되면 N + 1이 그대로 발생함.

- Fetch Join은 명시적으로 JOIN + 로딩 방식을 지정하는 것이라 예측 가능함

- Fetch Join = Join으로 한번에 가져오면서 영속성 컨텍스트에도 올려라 라는 명령

### 실제 적용

```java
package com.running.app.global.osm.repository;

import com.running.app.global.osm.entity.OsmSplit;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface OsmSplitRepository extends JpaRepository<OsmSplit, Long> {

    // 최소 위경도, 최대 위경도로 만든 직사각형과 겹치는 경로 객체를 반환
    @Query("SELECT w FROM OsmSplit w WHERE ST_Intersects(w.geom, ST_MakeEnvelope(:minLng, :minLat, :maxLng, :maxLat, 4326))")
    List<OsmSplit> findWaysInBbox(
            @Param("minLng") Double minLng,
            @Param("minLat") Double minLat,
            @Param("maxLng") Double maxLng,
            @Param("maxLat") Double maxLat
    );
}
```

- 연관관계 설정 시 fetch type을 lazy로 설정해두어, Osmsplit 컬렉션 순회 중, Osm_ways 데이터 조회 시마다 쿼리 발생 -> N + 1 문제 발생

- fetch join으로 쿼리 수 단 한번으로 줄임

---

# 2026-05-06

> 출처: develop 브랜치 본인 커밋 — `fc35fda`, `1eac137`, `91af12c` 작업 1: 에디터 삭제 API (`DELETE /v1/editor`) — `S14P31A103-273` 작업 2: OSM 도로 표시 줌 레벨 임시 완화 — `S14P31A103-340` 회고 관점: 백엔드 신입 취준생이 "면접에서 설명할 수 있는 수준으로" 무엇을 배웠는가 / 무엇을 더 봤어야 했는가

---

## [작업 1] 에디터 삭제 API — `DELETE /v1/editor?courseId=...`

### 1. CASCADE 에 의존하지 않고, 자식부터 명시적으로 삭제

```java
courseDistrictRepository.deleteByCourseId(courseId);   // 자식 먼저
courseRepository.deleteById(courseId);                 // 부모 나중
```

- 왜 CASCADE 가 아니라 두 줄로 풀어 썼나
  - DB 레벨 `ON DELETE CASCADE` 는 빠르지만 **JPA 영속성 컨텍스트와 어긋난다**. 1차 캐시에 남은 `CourseDistrict` 들은 여전히 살아 있는 것으로 보임 → 같은 트랜잭션 안에서 후속 쿼리가 일관성 깨짐.
  - JPA 의 `cascade = CascadeType.REMOVE` 는 부모 엔티티를 가져온 다음 자식들도 같이 SELECT 해야 함 → 자식이 많으면 비용 증가.
  - 그래서 **자식 일괄 DELETE 쿼리 한 방 + 부모 DELETE 한 방** 이 가장 가볍다.
- 순서가 핵심: 부모를 먼저 삭제하면 `course_district.course_id` 의 FK 제약을 위반.

> 면접 한 줄: "CASCADE 는 편하지만 영속성 컨텍스트와 어긋날 위험이 있어서, 의도가 분명할 때는 자식 → 부모 순으로 직접 DELETE 쿼리를 발행하는 쪽을 택했습니다."

### 2. 공유 엔티티(Track) 의 동반 삭제 조건

```java
Long trackId = course.getTrack().getTrackId();          // 캐싱
courseDistrictRepository.deleteByCourseId(courseId);
courseRepository.deleteById(courseId);

if (!runningRecordRepository.existsByTrack_TrackId(trackId)) {
    trackRepository.deleteById(trackId);
}
```

- Track 은 Course 만 참조하는 게 아니다. **RunningRecord 도 Track 을 가리킬 수 있다** → Track 을 무조건 같이 지우면 RunningRecord 의 dangling reference 발생.
- 그래서 `existsByTrack_TrackId` 로 "이 Track 을 가리키는 RunningRecord 가 있나?" 를 먼저 묻고, 없을 때만 동반 삭제.
- 이 패턴은 **참조 카운팅(reference counting)** 의 아주 단순한 형태. 본격 도입 안 해도, "참조자가 있는지" 만 확인하면 안전 삭제가 된다.

> 면접 한 줄: "Track 은 여러 도메인이 공유하는 자원이라, 삭제 요청한 도메인 외에 다른 참조자가 없을 때만 동반 삭제하도록 했습니다. 사실상 reference counting 의 1단계 적용입니다."

### 3. ID 캐싱 — 영속성 컨텍스트에서 사라지기 전에 미리 빼둔다

```java
Long trackId = course.getTrack().getTrackId();   // 먼저 캐싱
courseRepository.deleteById(courseId);           // 이 시점 이후 course.getTrack() 위험
```

- Course 삭제 후 `course.getTrack()` 을 호출하면, 영속성 컨텍스트에서 detach 된 엔티티에 lazy 접근 → `LazyInitializationException` 가능성.
- 미리 primitive 한 ID 만 뽑아두는 게 안전.
- 더 깊이 들어가면: 1차 캐시에서 제거된 엔티티의 프록시 필드 접근 동작은 구현체마다 다름.

> 면접 한 줄: "삭제 직전 엔티티에서 필요한 값을 미리 뽑아두는 건, lazy proxy 가 detach 이후에도 안전하게 동작하리란 보장이 없기 때문입니다."

### 4. 4가지 응답 분기 — 5/7 의 원형

| 케이스      | 응답  | 의미                               |
| -------- | --- | -------------------------------- |
| 로그인 안 됐다 | 401 | (JwtFilter 가 처리)                 |
| 없는 코스    | 404 | `COURSE_NOT_FOUND`               |
| 남의 코스    | 403 | `FORBIDDEN`                      |
| 이미 등록 완료 | 400 | `ALREADY_REGISTERED_COURSE` (신설) |

- `ALREADY_REGISTERED_COURSE` 를 새로 만든 이유: 기존 400 코드들로는 "왜 안 되는지" 클라이언트가 분기 못 함.
- 이 결정은 5/7 의 `EDITOR_NOT_EDITABLE` 신설과 똑같은 원칙. **에러는 의미 단위로 쪼갠다.**

### 5. 코드 한 곳에 있던 잠재 버그 — `Long` 비교

```java
if (course.getMemberId().longValue() != member.getMemberId()) { ... }
```

- 좌변은 `long`(primitive), 우변은 `Long`(객체) → 박싱/언박싱이 일어나며 `!=` 가 primitive 비교로 동작 → 의도대로 작동.
- 만약 둘 다 `Long` 이었다면 `!=` 가 **참조 비교** 가 되어, 캐시 범위(-128~127) 밖에서는 같은 값이어도 다르다고 판단했을 것.
- 이 코드는 우연히 안전한 형태지만, **명시적으로 `equals` 를 쓰는 게 정석**.

> 면접 한 줄: "박싱 타입의 동등성 비교는 `==` 가 아니라 `equals` 로 해야 합니다. 이번 코드는 한쪽을 primitive 로 풀어서 우연히 안전하지만, 코드 읽는 사람이 헷갈리지 않게 `equals` 로 명시하는 쪽이 더 낫습니다."

### 6. Swagger 를 본 로직과 같은 차수 안에서 푸시

- 본 로직 커밋(10:56) → 2분 뒤 Swagger 커밋(10:58).
- **API 명세는 코드와 같은 PR/일급 산출물로 다룬다** 는 습관. 명세가 뒤늦게 따라오면 FE 와 합의가 깨진다.

---

## [작업 2] OSM 도로 표시 줌 레벨 임시 완화

```diff
- final int MIN_ZOOM = 16;
+ // TODO: 현재는 테스트를 위해 모든 줌 레벨 허용
+ final int MIN_ZOOM = 10;
```

3줄짜리 변경이지만 배울 점이 있다.

- **매직 넘버를 상수로 미리 뽑아두면 변경 비용이 1줄로 줄어든다**. 만약 `if (zoom < 16)` 처럼 in-line 으로 박혀 있었다면 grep 으로 다 찾아야 했을 것.
- **임시 변경이라는 의도를 TODO 주석으로 남긴다**. 6개월 뒤에 누가 보면 "왜 10 이지?" 가 아니라 "아 테스트용이고, 원래대로 16 으로 복귀해야 함" 으로 읽힌다.
- 다만 진짜 안전한 패턴은 **환경 변수로 빼는 것** — `@Value("${osm.min-zoom:16}")`. 그러면 prod 는 16, dev/test 는 10 으로 두고 코드 수정 없이 분기 가능.

> 면접 한 줄: "환경별로 달라야 하는 임계값은 코드 상수보다 설정으로 빼는 게 맞다고 봅니다. 이번엔 임시였지만, 같은 패턴이 두 번 반복되면 application.yml 로 옮기는 시그널입니다."

---

## 더 봤어야 했던 / 면접에서 따라올 만한 후속 질문

### A. soft delete vs hard delete

- 지금은 hard delete(`DELETE FROM`). 한 번 지우면 끝.
- 운영 관점에서:
  - 사용자가 실수로 지웠을 때 복구 불가.
  - 분석/감사 로그용 데이터가 같이 사라짐.
- **soft delete** 패턴: `deleted_at` 컬럼을 추가하고 그것만 UPDATE → 조회 쿼리는 `WHERE deleted_at IS NULL` 필터.
- 단점: 모든 조회 쿼리에 필터 강제, 누락 시 데이터 새어 나옴 → `@Where(clause = "deleted_at IS NULL")` 또는 Hibernate `@SQLDelete` 같은 도구가 필요.
- 이번 도메인은 "에디터에서 미등록된 임시 코스" 라 hard delete 가 합리적이지만, **등록된 코스를 지운다면 soft delete 가 정답**. 그래서 `ALREADY_REGISTERED_COURSE` 가드가 들어간 것.

> 면접 한 줄: "이번 API 가 등록 전 임시 데이터만 삭제하도록 게이트한 것은 우연이 아니라, hard delete 의 위험을 줄이려고 의도적으로 좁힌 범위입니다. 등록된 코스 삭제는 soft delete 로 분기해야 한다고 봅니다."

### B. 동시성 — 동시에 두 번 DELETE 요청

- 사용자가 더블 클릭하거나, 두 탭에서 같은 코스를 동시에 삭제하면?
- 첫 트랜잭션이 부모 DELETE 까지 끝내기 전까지 두 번째도 같은 row 를 보고 통과 → 두 번째는 `DELETE` 시 0 rows affected 로 끝남.
- JPA `deleteById` 는 row 가 없으면 `EmptyResultDataAccessException` 을 던질 수 있음. 즉 두 번째 호출이 500 응답 가능.
- 해결: `existsById` 로 선행 검사하고 없으면 404 로 변환, 또는 `@Modifying @Query` 로 DELETE 쿼리 결과를 받아 처리.

### C. orphan Track — 동반 삭제 누락

- 흐름 마지막의 "RunningRecord 가 미참조 시에만 Track 삭제" 는 **현재 시점** 의 참조만 본다.
- 만약 트랜잭션 격리수준에 따라, Course 삭제와 동시에 다른 트랜잭션이 `INSERT INTO running_record(track_id=...)` 를 했다면? → 첫 트랜잭션이 "참조 없음" 으로 판단하고 Track 삭제 → RunningRecord 가 dangling.
- 해결: `SELECT ... FOR UPDATE` 로 Track 행을 잠그거나, 격리수준을 `SERIALIZABLE` 로 올림 — 둘 다 비용이 커서 실서비스에서는 보통 **dangling row 정리 배치** 로 보완.

### D. RESTful — `DELETE /v1/editor?courseId=...` 가 정말 맞나

- REST 컨벤션상 자원은 URI path 에. `DELETE /v1/editor/{courseId}` 또는 더 자원 중심으로 `DELETE /v1/course-drafts/{courseId}` 가 정석.
- query param 으로 받는 건 검색/필터에 쓰는 패턴.
- 5/7 의 PATCH 가 `PATCH /v1/editor/{courseDraftId}` 인 것과 일관성도 어긋남.

> 답안: "DELETE 의 대상 자원은 path 에 두는 게 컨벤션입니다. 5/7 작업에서 PATCH 를 `/{id}` 로 갔으니, 같은 도메인에서 일관성을 맞추려면 이 API 도 다음 정리 때 path variable 로 옮기는 게 맞습니다."

### E. Idempotency

- DELETE 는 **멱등** 해야 한다(RFC). 같은 요청을 두 번 보내도 결과가 같아야 함.
- 첫 호출: 200, 삭제 완료. 두 번째 호출: 현재 코드는 `COURSE_NOT_FOUND` 로 404 → **결과가 달라짐 → 멱등 아님**.
- 정석: "이미 삭제됨" 도 204 No Content 또는 200 OK 로 응답해서 멱등 보장.
- 실무에서는 양쪽 다 받아들임 (404 도 흔하긴 함). 면접관 취향 갈리는 영역.

### F. CASCADE 와 JPA orphanRemoval 의 차이

지금은 직접 DELETE 쿼리를 발행했지만, 후보였던 두 가지:

- **DB CASCADE**: FK 에 `ON DELETE CASCADE`. 빠르고 한 줄. 영속성 컨텍스트는 안 알아줌.
- **JPA cascade=REMOVE**: 부모 엔티티에 `@OneToMany(cascade=REMOVE)`. 영속성 컨텍스트는 일관성 유지, 대신 자식들을 다 로드.
- **orphanRemoval=true**: 자식 컬렉션에서 자식을 빼면 자동 DELETE. "부모를 지운다" 가 아니라 "자식을 떼낸다" 의미.

세 가지를 구분 못 하면 면접에서 무너질 수 있는 지점.

> 답안: "DB CASCADE 는 DB 가 책임지고 빠르지만 JPA 와 동기화 안 됨, JPA cascade=REMOVE 는 영속성 컨텍스트와 일관성 유지하지만 자식 로드 비용, orphanRemoval 은 컬렉션 조작 기반이라 의미가 다릅니다."

---

## 핵심 한 줄 요약

> **삭제 API 는 "이 자원이 누구에게 어떻게 가리켜지고 있는가" 를 먼저 답하는 작업이다.** 부모/자식 관계는 FK 순서로, 공유 자원은 참조자 존재 여부로, 시점 분기는 도메인 상태(`registered_at`)로 나눈다. 이 세 축이 5/7 의 "상태 모델 = 권한 모델" 로 자연스럽게 이어졌다.

---

# 2026-05-07

> 출처: worklog/자율/2026-05-07_에디터-수정-API.md
> 작업: 에디터 수정 API (`PATCH /v1/editor/{courseDraftId}`) 구현
> 회고 관점: 백엔드 신입 취준생이 이 작업에서 "면접에서 설명할 수 있는 수준으로" 무엇을 배웠는가 / 무엇을 더 봤어야 했는가

---

## 오늘 배운 것 (배운 것을 면접 질문 형태로 정리)

### 1. PATCH vs PUT — 부분 수정에는 왜 PATCH 인가

- **PUT**: 리소스의 전체 표현(full representation)을 교체한다. 보내지 않은 필드는 비워지거나 기본값으로 돌아간다고 약속하는 메서드다.
- **PATCH**: 리소스의 부분(partial) 갱신. 보낸 필드만 바꾸고 나머지는 유지한다. RFC 5789.
- 이번 API 는 제목 / 좌표 / (좌표에서 파생되는) distance·difficulty 만 갱신했으므로 PATCH 가 맞다. PUT 으로 받았다면 "안 보낸 필드는 어떻게 처리할지" 라는 의미 모호함이 클라이언트마다 다르게 해석된다.

> 면접 한 줄: "수정은 전체 교체가 아니라 일부 필드의 부분 갱신이라서, 의미상 PATCH 를 선택했습니다."

### 2. 요청 DTO 를 새로 만들 것인가, 저장용을 재사용할 것인가

오늘 선택은 **재사용** (`EditorRequest.SaveRequest` 그대로 사용).

판단 기준이 명확했다:

- 형식이 **현재** 같다는 이유만으로 재사용하는 게 아니다.
- "앞으로 수정 전용 필드가 생길 도메인인가?" 를 물었고, 코스 드래프트 수정에는 그럴 만한 필드(예: 변경 사유, 이전 버전 참조)가 안 보였다.
- 그렇다면 분리는 변경 시 양쪽 동기화 비용만 늘린다 → 재사용.

> 면접 한 줄: "DTO 분리 여부는 '현재 형식이 같은가' 가 아니라 '진화 방향이 다른가' 로 판단해야 한다고 봅니다. 같은 방향으로 진화할 도메인은 묶는 게 변경 비용이 더 낮습니다."

### 3. 에러 코드는 의미 단위로 쪼개야 한다

기존 코드를 재사용하려는 유혹이 있었지만 거절했다.

- `ALREADY_REGISTERED_COURSE` → 메시지가 "등록 완료한 코스는 삭제 불가" 인데, 지금은 DONE / REGISTERED / 그 외 상태 전부 잡아야 한다. 메시지 의미가 어긋남.
- `BAD_REQUEST` → 클라이언트가 "왜 실패했는지" 분기할 수 없다.
- 결국 `EDITOR_NOT_EDITABLE` 신설.

핵심은 **클라이언트의 분기 능력**. 같은 400 이라도 "검증 실패(좌표 불가)" 와 "상태 때문에 수정 불가" 는 사용자에게 보여야 할 메시지·UI 가 다르다 → 에러 코드를 합치는 순간 FE 가 분기 못 한다.

### 4. HTTP 상태 코드 4가지 분기

이번 API 의 실패 케이스:

| 상황                          | 응답  | 의미                            |
| --------------------------- | --- | ----------------------------- |
| 토큰 없음/만료                    | 401 | 인증 안 됨 (Authentication)       |
| 남의 draft 수정 시도              | 403 | 인증은 됐지만 권한 없음 (Authorization) |
| 존재하지 않는 draft               | 404 | 리소스 없음                        |
| READY 가 아닌 draft / 좌표 검증 실패 | 400 | 클라이언트가 보낸 요청 자체가 처리 불가        |

> 면접 한 줄: "401 과 403 의 차이는 '당신이 누군지 모른다' vs '당신이 누군지는 알지만 이 리소스를 만질 권한은 없다' 입니다."

### 5. 상태 전이 모델을 권한 모델로 사용한다 (오늘의 가장 큰 것)

`CourseDraft` 가 `READY → DONE → REGISTERED` 로 흐른다.
"수정 가능 조건이 뭐냐" 에 대해 별도 권한 테이블이나 정책 메서드를 두지 않고, **`status == READY` 하나로 정의** 했다.

왜 이게 깔끔한가:

- DONE 인 draft 는 이미 그 좌표로 사용자가 실제로 뛰어서 RunningRecord 가 생겼다. 좌표를 수정하면 record 가 가리키던 경로가 사라진다.
- REGISTERED 인 draft 는 Course 가 만들어졌다. 좌표 수정은 Course 입장에서 정합성 파괴.
- 즉 "READY 가 아니면 수정 금지" 라는 한 줄 검증이 곧 **하위 데이터 정합성 보호 규칙** 과 같다.

> 면접 한 줄: "도메인의 상태 모델 자체가 권한 모델 역할을 하도록 설계했습니다. 별도 권한 정책을 추가하지 않고 상태 하나로 '이 데이터에 어떤 행위가 허용되는가' 를 표현하면 검증이 한 곳에 모입니다."

### 6. 엔티티를 갱신할 때: in-place vs INSERT + swap + DELETE

오늘 Track 갱신 방식은 후자였다.

- in-place 갱신을 선택할 수 없었던 이유: `Track` 이 다른 팀원 영역이라 `changeXxx` 같은 도메인 메서드를 추가할 수 없었음.
- 그래서 새 Track 을 INSERT → `draft.track` 을 새 것으로 swap → 기존 Track 은 RunningRecord 가 참조하지 않을 때만 DELETE.

배운 점:

- 코드 소유권(ownership) 경계가 곧 설계 제약이다. 협업하는 코드베이스에서 "남의 엔티티를 바꾸지 않고 내가 할 수 있는 일" 을 먼저 따져야 함.
- INSERT/swap 방식이 부수 이득을 줬다: 저장 흐름의 헬퍼(`createMultiLineString`, `createTrackFromEditor`) 를 그대로 재사용 → "저장과 수정이 같은 코드를 탄다" 는 일관성.
- 안전 삭제 조건이 명시적이다: "READY 상태라 record 참조가 없을 때만" → 데이터 누락 가능성을 도메인 상태로 차단.

> 면접 한 줄: "이 패턴은 본질적으로 불변 객체 다루듯이 한 것입니다. 기존 Track 을 mutate 하는 대신 새로 만들고 참조만 swap 했기 때문에, 동시성/캐시/이력 관리 측면에서 부작용이 작습니다."

### 7. 응답 Contract 를 상세 조회와 동일하게 — 검증 응답의 `isValidRoute` 를 뺀 이유

명세서에는 `isValidRoute` 가 있었지만 뺐다.

- 검증 실패는 `INVALID_ROUTE` 예외로 끊긴다 → 200 응답이 돌아간 시점에 `isValidRoute` 는 무조건 true → 정보량 0.
- 정보량 0 인 필드 하나를 위해 응답 타입을 별도로 두면, 상세조회 응답과 수정 응답이 미묘하게 달라져서 FE 가 두 파서를 유지해야 함.
- 그래서 `DraftDetailResponse` 로 통일.

> 면접 한 줄: "응답에 의미 있는 변동성이 없는 필드는 빼는 게 맞다고 봅니다. API 응답 contract 의 일관성이 클라이언트 측 코드 재사용성을 좌우합니다."

### 8. 트랜잭션과 검증 실패의 관계

흐름에서 5번이 핵심:

```
5. 좌표 정렬 + OSM walkable 검증 (실패 시 INVALID_ROUTE → 트랜잭션 롤백)
```

- 검증을 INSERT/swap 보다 **앞** 에 두면, 검증 실패 시 어차피 새 Track INSERT 자체가 일어나지 않는다 → 롤백 부담 최소.
- 그래도 트랜잭션으로 감싸야 하는 이유: 6~9 단계(INSERT, swap, 기존 Track DELETE) 중 어딘가 실패 시 부분 반영을 막아야 함.

> 면접 한 줄: "검증을 mutation 이전에 두는 건 '실패는 빨리 끝낸다' 원칙입니다. 트랜잭션은 mutation 구간을 묶기 위함이고요."

---

## 더 봤어야 했던 / 면접에서 따라올 만한 후속 질문

오늘 작업에서 직접 풀진 않았지만, 면접관 입장에서 충분히 깊게 파고들 수 있는 지점들. **지금 코드는 작동하지만**, 아래 질문이 들어오면 답이 약해진다.

### A. 동시성 — 같은 draft 를 두 번 수정 요청이 들어오면?

- 사용자가 두 탭에서 같은 draft 를 수정하면 두 트랜잭션이 동시에 status 검증 → 둘 다 통과 → 둘 다 새 Track 을 INSERT → 마지막에 swap 한 쪽만 반영, 다른 쪽 Track 은 orphan 으로 떠있다.
- 해결 옵션:
  - **낙관적 락(Optimistic Lock)** : `CourseDraft` 에 `@Version` 추가 → 두 번째 트랜잭션이 commit 시점에 `OptimisticLockingFailureException` 으로 실패.
  - **비관적 락(Pessimistic Lock)**: `SELECT ... FOR UPDATE` → 첫 트랜잭션이 끝날 때까지 두 번째는 대기.
- 단일 사용자가 자기 draft 만 건드리는 도메인이라 충돌 빈도는 낮음 → 낙관적 락이 합리적.

> 더 본 면접용: "에디터는 충돌 빈도가 낮은 쓰기 패턴이라 낙관적 락을 선택할 겁니다. 충돌 자체보다 충돌 시 사용자에게 어떤 메시지를 줄지가 더 중요합니다."

### B. orphan Track — 부분 실패 시 청소는 어떻게?

흐름 9번 `RunningRecord 가 미참조 시 trackRepository.deleteById` 는 swap 한 **이전** Track 을 청소한다.
그런데 만약:

- 새 Track INSERT 는 성공
- swap 직전에 애플리케이션이 죽음

이라면 **새로 INSERT 한 Track 이 orphan 으로 떠 있을 수 있다**. 트랜잭션 안에 INSERT 가 있으니 commit 전이면 롤백되긴 하지만, JPA flush 타이밍과 트랜잭션 경계를 잘못 잡으면 새는 경우가 생긴다.

→ **dangling row 청소 배치(cleanup job)** 가 운영 단계에서 필요할 수 있다. 면접관이 "이 시스템 1년 운영하면 데이터가 얼마나 쌓일까요?" 물으면 이 답이 나와야 함.

### C. 도메인 이벤트 — Track 이 바뀌었음을 누가 알아야 하나

지금은 READY 상태라 하위 데이터가 없어 신경 안 써도 됐다.
그런데 만약 "draft 좌표가 바뀌면 알림 보내야 한다" 같은 요구가 추가되면?

- 옵션 1: Service 안에서 직접 알림 호출 → 결합도 증가, 트랜잭션 안에서 외부 호출 위험.
- 옵션 2: **도메인 이벤트** 발행 (`DraftCoordinatesChanged`) → 트랜잭션 commit 후 리스너가 처리.
- 옵션 3: **Transactional Outbox** 패턴 → 같은 트랜잭션에 outbox 테이블에 이벤트 INSERT, 별도 워커가 발송.

> 더 본 면접용: "지금은 필요 없지만, 트랜잭션 안에서 외부 호출을 직접 하면 외부 시스템이 느릴 때 DB 트랜잭션이 같이 길어집니다. 이벤트 분리는 그 결합을 끊는 도구입니다."

### D. RESTful 관점에서 — `/v1/editor/{id}` 가 정말 좋은 URI 인가

- REST 컨벤션에서 URI 는 리소스 이름(명사). `editor` 는 행위/UI 모드에 가까운 단어다.
- 더 자원 중심이라면 `/v1/course-drafts/{id}` 가 정확하다.
- 이미 굳어진 명세라 바꾸진 않았지만, 면접관이 짚을 수 있다.

> 답안: "리소스 자체는 course draft 입니다. 'editor' 는 클라이언트의 사용 맥락(에디터 화면) 인데, URI 는 사용 맥락이 아니라 리소스를 가리키는 게 맞다는 의견에 동의합니다. 다음 마이그레이션 때 정리할 후보입니다."

### E. PATCH 의 멱등성

- RFC 상 PATCH 는 **멱등하지 않다**(non-idempotent). 같은 요청 두 번 보내면 결과가 같을 수도, 다를 수도 있다.
- 이번 API 는 형식상 같은 요청을 두 번 보내도 결과가 같다(같은 좌표로 같은 distance/difficulty 가 계산됨) → 사실상 멱등하게 동작.
- 하지만 그건 우리 구현의 우연한 성질이지, PATCH 라는 메서드의 보장은 아니다.

> 답안: "PATCH 자체는 멱등성을 보장하지 않습니다. 이번 구현은 우연히 멱등하게 동작하지만, 그건 메서드의 약속이 아니라 우리 구현 결과입니다. 멱등성이 필요한 클라이언트는 별도로 멱등키(Idempotency-Key) 헤더를 사용하는 게 정석입니다."

### F. State Pattern / Aggregate Root 관점에서 본 today

오늘 한 일을 DDD 용어로 다시 보면:

- `CourseDraft` 가 **Aggregate Root** 이고 `Track` 은 그 안의 엔티티/값객체에 가깝다.
- 그런데 `Track` 의 변경 메서드를 추가 못 해서(소유권 경계) Aggregate 밖에서 INSERT/swap 하고 있다 → 진짜 DDD 적으로는 Aggregate 내부 캡슐화가 깨진 상태.
- 면접에서 "이 코드를 DDD 관점에서 평가해 보세요" 가 들어오면, 이 약점을 먼저 인정하고 "팀 경계 때문에 그렇게 됐다" 로 풀어야 한다. 합리화하면 점수 깎임.

---

## 핵심 한 줄 요약

> **도메인의 상태 모델을 권한 모델로 사용하면 검증이 한 곳에 모이고 하위 데이터 정합성이 부수적으로 따라온다.** 그리고 API 설계의 작은 결정들(DTO 재사용 여부, 에러 코드 신설 여부, 응답 contract 통일) 은 "현재 같은가" 가 아니라 "앞으로 같은 방향으로 변할 것인가" 로 판단해야 한다.

---

# 2026-05-08

> 출처: develop 브랜치 본인 커밋 — `83bfb2c`, `d86317e`, `2e82665`, `fcd6f27`, `b525165` 작업 1: 에디터 이미지 저장 로직 추가 — `S14P31A103-361` 작업 2: Redis 설정 파일 작성 — `S14P31A103-372` 회고 관점: 백엔드 신입 취준생이 "면접에서 설명할 수 있는 수준으로" 무엇을 배웠는가 / 무엇을 더 봤어야 했는가

---

## [작업 1] 에디터 이미지 저장 — 트랜잭션 / 디스크 IO / 보상 처리

이 작업은 오늘 한 일 중 가장 무겁고, 백엔드 설계 결정이 4개 겹쳐 있다.
하나씩 풀어 설명할 수 있어야 한다.

### 1. 트랜잭션 안에 디스크 IO 를 넣지 않는다

**원래 코드**:

```java
@Transactional
public SaveResponse save(...) {
    // 1. Member 조회
    // 2. 좌표 검증
    // 3. Track 영속화
    // 4. CourseDraft 영속화
}
```

**바뀐 코드**:

```java
// 트랜잭션 밖
public SaveResponse save(...) {
    String imageUrl = trackImageStorageService.storeFromBase64(...);  // 디스크 IO
    try {
        return editorDraftSaver.save(loginId, request, imageUrl);     // 트랜잭션 안
    } catch (RuntimeException e) {
        trackImageStorageService.deleteByUrl(imageUrl);               // 보상
        throw e;
    }
}
```

- 핵심: **디스크 쓰기 시간만큼 DB 커넥션이 묶이는 걸 막는다.**
- 트랜잭션 안에서 `Files.write(...)` 하면, 디스크가 느린 순간(예: EBS 지연) DB 커넥션이 그 시간만큼 idle 상태로 점유됨 → 커넥션 풀 고갈.
- 디스크 IO 를 트랜잭션 **전** 에 끝내고, DB 작업만 트랜잭션으로 묶는 게 정석.

> 면접 한 줄: "외부 자원(디스크/네트워크) 호출은 트랜잭션 밖으로 빼는 게 원칙입니다. 트랜잭션은 커넥션을 점유하는 자원이라, IO 시간만큼 커넥션을 묶으면 풀이 빠르게 마릅니다."

### 2. Self-invocation 회피 — 별도 빈으로 분리

```java
@Component
public class EditorDraftSaver {
    @Transactional
    public SaveResponse save(...) { ... }
}
```

- 왜 `EditorService` 안에 `@Transactional` private 메서드로 두지 않았나?
- **Spring AOP 프록시는 외부에서 호출이 들어올 때만 작동**한다. 같은 클래스 안에서 `this.save()` 를 호출하면 프록시를 거치지 않으므로 `@Transactional` 이 안 먹는다.
- 우회법 3가지:
  - **자기 자신을 빈으로 주입**(`@Autowired private EditorService self`) — 코드 흉함.
  - **AspectJ 적용** — 컴파일 타임 위빙 필요.
  - **별도 빈으로 분리** — 가장 깔끔. 책임 분리도 같이 됨.
- 그래서 `EditorDraftSaver` 라는 새 컴포넌트로 뺐다. **부수 효과로 책임이 더 명확해짐**: Facade(`EditorService`) 는 흐름 조립, Worker(`EditorDraftSaver`) 는 트랜잭션 안에서 DB 영속화만.

> 면접 한 줄: "같은 클래스 안의 self-invocation 은 프록시를 거치지 않아 `@Transactional` 이 무효화됩니다. 그래서 트랜잭션 단위를 별도 빈으로 분리했고, 부수적으로 Facade-Worker 구조가 자연스럽게 잡혔습니다."

### 3. 보상 트랜잭션 (Compensating Transaction)

```java
try {
    return editorDraftSaver.save(loginId, request, imageUrl);
} catch (RuntimeException e) {
    trackImageStorageService.deleteByUrl(imageUrl);
    throw e;
}
```

- 디스크와 DB 는 **다른 자원**. 같은 트랜잭션으로 묶을 수 없음(XA 분산 트랜잭션 빼면).
- DB 가 롤백되면 디스크의 파일은 그대로 남아 **orphan** 이 됨.
- 그래서 DB 실패 시 디스크 파일을 직접 지운다 — 이게 **보상 트랜잭션** 의 가장 단순한 형태.

핵심 디테일 두 개:

#### (a) 보상 실패는 원인 예외를 가리지 않는다

```java
public void deleteByUrl(String url) {
    try {
        Files.deleteIfExists(targetPath);
    } catch (IOException e) {
        log.warn("track image cleanup failed: {}", targetPath, e);   // throw 아니고 log!
    }
}
```

- 보상이 실패해도 던지지 않는 이유: 보상 단계에서 던지면 **진짜 원인 예외(예: `INVALID_ROUTE`)** 가 가려진다.
- 사용자에게 보여야 할 메시지는 "보상 파일 삭제 실패" 가 아니라 "뛸 수 없는 길" 임.
- orphan 파일은 운영팀이 배치로 청소.

> 면접 한 줄: "보상 실패는 로그만 남깁니다. 사용자가 받을 응답은 원인 예외에서 와야 하기 때문에, 보상 단계에서 던지면 진짜 원인이 가려집니다."

#### (b) Path traversal 방어

```java
String fileName = url.substring(slashIndex + 1);
if (fileName.contains("..") || fileName.contains("/") || fileName.contains("\\")) {
    return null;   // 거부
}
```

- 공개 URL 의 마지막 path 세그먼트를 파일명으로 쓴다.
- 만약 URL 에 `..` 나 슬래시가 끼면 `trackImageDirectory.resolve(fileName)` 이 의도치 않은 경로로 빠질 수 있음.
- 이번 흐름에서는 URL 을 우리가 만든 거라 위험은 낮지만, **방어적으로 보수적인 게 맞다** — 미래에 외부 입력이 들어올 가능성 차단.

### 4. Base64 Data URI 파싱

```java
if (dataUri.startsWith("data:image/png;base64,")) {
    extension = ".png";
    base64Payload = dataUri.substring("data:image/png;base64,".length());
} else if (dataUri.startsWith("data:image/jpeg;base64,")) {
    extension = ".jpg";
    ...
} else {
    throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "PNG 또는 JPEG data URI 만 허용합니다.");
}
```

- FE 가 multipart 가 아닌 **JSON body 안에 base64 문자열로** 썸네일을 보냄.
- 왜 multipart 아닌가? — FE 에서 좌표 + 제목 + 썸네일을 한 번에 보내는 게 단순함. multipart 는 JSON 과 섞을 때 다루기 번거로움.
- 대신 서버는 본문 크기가 커진다 → 적절한 max-size 설정 필요(`spring.servlet.multipart.max-request-size` 와는 다른, body 크기 제한).
- 보안: **mime prefix 와 실제 바이트 타입은 일치 보장 X**. 클라이언트가 `data:image/png;base64,...` 로 시작하지만 내용은 실행파일을 base64 한 것일 수도 있음. 이미지 매직 넘버 검증이 더 엄격한 방어.

> 면접 한 줄: "data URI prefix 만 검사하면 mime spoofing 에 약합니다. 진짜 안전한 방법은 ImageIO 로 디코딩 시도해서 실패하면 거부하는 거지만, 이번엔 입력 출처가 우리 앱이라 비용 대비 효과로 prefix 검사만 채택했습니다."

### 5. 충돌 해결 커밋의 의미 (`d86317e`)

- 11:30 본 로직 → 13:41 충돌 해결.
- 이 사이에 develop 으로 **에디터 상세 조회(`-271`)** 가 머지되면서 `EditorController`, `EditorService` 가 같이 바뀜.
- 충돌 해결 = "내 변경 + 동료 변경" 을 의미가 깨지지 않게 다시 조립. 같은 파일에 두 PR 이 동시에 들어올 때 항상 일어남.
- **이걸 안 하면 develop 이 깨진다** → CI 가 무너짐 → 모든 사람의 빌드가 멈춤.
- 교훈: 같은 도메인의 작업은 PR 끼리 가능한 한 직렬화하는 게 좋다. 또는 PR 자체를 작게 쪼개서 머지 충돌 면적을 줄인다.

---

## [작업 2] Redis 설정 — `RedisConfig` 빈 등록

```java
@Configuration
public class RedisConfig {

    @Bean
    public RedisTemplate<String, String> redisTemplate(RedisConnectionFactory cf) {
        // 단일 문자열/숫자용
        ...
    }

    @Bean
    public RedisTemplate<String, Object> redisObjectTemplate(RedisConnectionFactory cf) {
        // 객체용 — GenericJackson2JsonRedisSerializer 사용
        ...
    }
}
```

### 1. 왜 RedisTemplate 빈을 두 개 등록했나

- **`String → String`**: 카운트, 토큰, 단순 키-값. 직렬화 오버헤드 0.
- **`String → Object`**: DTO 같은 다중 필드 객체. `GenericJackson2JsonRedisSerializer` 가 **타입 정보를 JSON 에 같이 넣어줌** → 역직렬화 시 어떤 클래스로 복원할지 알 수 있음.
- 굳이 둘로 나눈 이유: 단순 값까지 JSON 직렬화 거치면 `"123"` 가 `"123"` 로 저장돼서 사람이 redis-cli 로 봤을 때 따옴표 끼고 보임 + 직렬화 비용 발생.

> 면접 한 줄: "Redis 의 직렬화 비용은 작아 보여도 호출 빈도가 높은 카운터에서는 누적됩니다. 단순 값과 객체를 다른 template 으로 분리한 건 직렬화 비용과 가독성 둘 다 챙기려는 결정입니다."

### 2. Key Serializer 는 왜 `StringRedisSerializer` 인가

- 기본값은 `JdkSerializationRedisSerializer` → 키가 `\xac\xed\x00\x05...` 같은 바이너리로 저장됨.
- redis-cli 로 `KEYS *` 쳤을 때 사람이 못 읽음 → 운영/디버깅 지옥.
- 키는 무조건 `StringRedisSerializer` 로 맞추는 게 사실상 표준.

### 3. 패키지 경로를 옮긴 두 번째 커밋 (`b525165`)

```
global.redis.config.RedisConfig
       ↓
global.config.RedisConfig
```

- 다른 Config 들이 `global.config` 에 있어서 통일.
- 작은 결정이지만: **도메인별로 폴더를 더 쪼개는 게 좋은가 vs 횡단 관심사는 한 곳에 모으는 게 좋은가** 의 트레이드오프.
- Config 는 횡단 관심사라 한 곳에 몰아두는 쪽이 IDE 에서 찾기 쉽다 → 통합 선택이 맞음.

---

## 더 봤어야 했던 / 면접에서 따라올 만한 후속 질문

### A. Redis 를 **왜** 도입하는가

- 오늘 한 작업은 "RedisTemplate 빈 등록" 까지. 정작 어떤 용도로 쓸지가 보이지 않음.
- 가능한 용도 5가지:
  1. **캐시** — DB 조회 결과 캐싱. 가장 흔함.
  2. **세션 스토어** — 멀티 인스턴스 환경에서 세션 공유.
  3. **분산 락** — `SETNX` 또는 Redisson 으로 동시성 제어.
  4. **rate limiting** — 사용자별 호출 빈도 제한.
  5. **PubSub / Streams** — 실시간 이벤트.
- 면접관이 "왜 도입했냐" 물으면 위 5개 중 어떤 거였는지 답할 수 있어야 함.

> 더 본 면접용: "Redis 도입의 의사결정은 보통 '관계형 DB 가 못 하는 일' 에서 출발합니다. TTL, 원자적 INCR, 분산 락, 빠른 만료 — 이런 요구가 생기면 그때 도입하는 게 맞습니다."

### B. 보상 트랜잭션 vs 분산 트랜잭션 vs Outbox

오늘 한 것은 가장 단순한 보상 트랜잭션. 더 큰 그림:

| 방식                         | 설명                                    | 트레이드오프                   |
| -------------------------- | ------------------------------------- | ------------------------ |
| **보상 트랜잭션 (Compensating)** | 실패 시 직접 되돌리는 로직 호출                    | 단순. 보상 자체가 실패할 수 있음      |
| **분산 트랜잭션 (XA, 2PC)**      | 두 자원을 하나의 트랜잭션으로 묶음                   | 무거움. 디스크는 XA 안 됨         |
| **Transactional Outbox**   | 같은 DB 트랜잭션에 이벤트 INSERT → 별도 워커가 후속 처리 | 디스크엔 안 맞음. 외부 시스템 호출에 적합 |
| **Saga**                   | 여러 단계를 각각 트랜잭션으로 쪼개고 각 단계마다 보상 정의     | 마이크로서비스에서 표준             |

이번 케이스(디스크 + DB) 는 보상 트랜잭션이 가장 적합. 만약 "DB 저장 + 외부 API 호출" 이었다면 Outbox 가 정답.

### C. 이미지 저장 — 로컬 디스크 vs S3

지금: EC2 로컬 디스크 + Nginx 정적 서빙.
실서비스 표준: **S3 + CloudFront**.

- 로컬 디스크의 문제:
  - **스케일 아웃 불가**: 인스턴스 늘리면 파일이 한 쪽 디스크에만 있음.
  - **디스크 가득 차면 서비스 다운**.
  - **백업/복구 책임이 우리 몫**.
- S3 의 장점:
  - 무한 용량, 99.999999999% 내구성.
  - CloudFront 와 결합 시 글로벌 캐시.
  - **Presigned URL** 패턴으로 FE 가 직접 업로드 → 서버 부담 0.
- 단점: 비용, 학습 곡선.

> 답안: "현재 구조도 작동합니다. 다만 현업에서는 인스턴스 스케일 아웃 시점에 로컬 디스크가 병목이 되므로 S3 + Presigned URL 로 옮기는 게 표준입니다."

### D. Base64 vs Multipart — 정말 base64 가 맞나

- base64 는 원본 바이트 대비 **약 33% 더 크다**. 1MB 이미지가 1.33MB 가 됨.
- HTTP 본문 크기 증가 → 네트워크 비용, 메모리 사용 증가.
- 그럼에도 base64 를 쓰는 이유:
  - JSON 한 번에 같이 보낼 수 있음 → FE 단순.
  - 멀티파트 파싱 안 해도 됨 → 서버 단순.
- 실서비스 패턴: **이미지는 별도 엔드포인트로 multipart 또는 Presigned URL** 로 올리고, 본 요청에서는 그 URL 만 받음.

> 답안: "본문 폭증을 감수하고 base64 를 택한 건 흐름 단순성 때문입니다. 이미지가 커지거나 동시 요청이 늘면, 업로드를 분리하는 게 맞다고 봅니다."

### E. 트랜잭션 분리에 의한 영속성 컨텍스트 분리

- `EditorService` (트랜잭션 X) → `EditorDraftSaver.save` (트랜잭션 O)
- 두 메서드는 **다른 영속성 컨텍스트** 를 가짐. `EditorService` 에서 미리 조회한 엔티티가 있어도 `EditorDraftSaver` 안에서는 detach 상태.
- 오늘 코드는 EditorService 에서 엔티티를 안 가져왔으니 문제없지만, 미래에 "Member 를 EditorService 에서 가져와서 넘기자" 하면 detach 문제로 LazyInitializationException 가능.

### F. base64 디코딩의 메모리 — 큰 이미지의 위험

```java
byte[] imageBytes = Base64.getDecoder().decode(base64Payload);
```

- 한 번에 전체를 메모리에 올림. 10MB 이미지면 13MB 문자열 + 10MB 바이트 배열이 동시에 힙에 있음.
- 동시 요청 100개면 1.3GB 가 휙 사라짐.
- 방어: **DTO 단계에서 길이 제한** (`@Size`) 또는 **Spring 의 `spring.servlet.multipart.max-request-size` 같은 본문 제한**.

### G. Redis 만으로 답이 안 되는 질문

- TTL 정책 (Eviction Policy): `allkeys-lru`, `volatile-ttl`, `noeviction` 등 — 메모리 가득 찼을 때 무엇을 버릴지.
- Persistence: **RDB(snapshot)** vs **AOF(append-only file)** — 재시작 시 데이터 보존.
- Cluster vs Sentinel — 고가용성/샤딩.
- 캐시 일관성 패턴: **Cache Aside**, **Write Through**, **Write Behind**.

이번 작업은 빈 등록까지라 자세히 다루진 못했지만, 면접에서 위 4개 중 하나는 무조건 들어옴.

---

## 핵심 한 줄 요약

> **외부 자원(디스크, 네트워크) 호출은 트랜잭션 밖으로, DB 작업만 트랜잭션 안으로 — 그리고 두 자원 사이의 일관성은 보상 트랜잭션으로 메운다.** 이 원칙이 self-invocation 회피(별도 빈 분리) → Facade-Worker 책임 분리로 자연스럽게 이어졌고, 결과적으로 트랜잭션 경계 / 책임 경계 / 에러 처리 경계 세 개가 모두 같은 선 위에 정렬되었다.

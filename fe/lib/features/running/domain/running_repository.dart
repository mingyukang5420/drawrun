import 'package:running/features/running/domain/running_session.dart';
import 'package:running/features/running/domain/run_start_response.dart';

// 러닝 데이터 영속화 계약(인터페이스). ViewModel 은 이 추상 타입에만 의존.
// session: 측정된 러닝 데이터 (거리/시간/경로 등 — 측정 결과)
// title: 사용자가 결과 화면에서 입력한 러닝 제목
// courseId: 코스 따라뛰기 모드일 때 코스 ID. 자유 러닝이면 null
// courseDraftId: 에디터 드래프트로 진입한 코스 ID. 자유 러닝/공식 코스면 null
// challengeId: 챌린지에 참여한 러닝일 때 챌린지 ID. 자유 러닝/단순 코스 따라뛰기면 null
//              BE 는 not-null 일 때만 챌린지 랭킹/통계에 집계한다.
// trackImageUrl: 경로 썸네일. 현재는 BE 미구현이므로 'tempValue' 고정 전달
abstract class RunningRepository {
  Future<void> save({
    required RunningSession session,
    required String title,
    required String trackImageUrl,
    int? courseId,
    int? courseDraftId,
    int? challengeId,
  });

  // 러닝 시작 — 카운트다운 진입 직후 한 번 호출.
  // courseId / courseDraftId 둘 다 null 이면 자유 러닝.
  // 응답으로 코스의 GPS 노드(있다면) 가 따라온다 — 호출처에서 state 에 보관해 활용.
  Future<RunStartResponse> startSession({
    int? courseId,
    int? courseDraftId,
  });
}
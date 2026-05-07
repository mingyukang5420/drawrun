import 'package:running/features/running/domain/running_session.dart';

// 러닝 데이터 영속화 계약(인터페이스). ViewModel 은 이 추상 타입에만 의존.
// session: 측정된 러닝 데이터 (거리/시간/경로 등 — 측정 결과)
// title: 사용자가 결과 화면에서 입력한 러닝 제목
// courseId: 코스 따라뛰기 모드일 때 코스 ID. 자유 러닝이면 null
// trackImageUrl: 경로 썸네일. 현재는 BE 미구현이므로 'tempValue' 고정 전달
abstract class RunningRepository {
  Future<void> save({
    required RunningSession session,
    required String title,
    int? courseId,
    String trackImageUrl = 'tempValue',  // TODO: 이미지 UUID 전송 로직 반영
  });
}
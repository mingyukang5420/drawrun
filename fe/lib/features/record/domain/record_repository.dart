import 'package:running/features/record/domain/running_record.dart';

// 기록 저장소 추상 인터페이스 (계약)
// Presentation 계층은 이 인터페이스만 알고,
// 실제 구현(RecordRepositoryImpl)은 Data 계층에서 제공
abstract class RecordRepository {
  // 서버에서 전체 러닝 기록 목록 조회
  Future<List<RunningRecord>> getRecords();
}

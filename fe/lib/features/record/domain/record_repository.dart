import 'package:running/features/record/data/record_summary_page.dart';
import 'package:running/features/record/domain/record_detail.dart';
import 'package:running/features/record/domain/record_stats.dart';

// 기록 저장소 추상 인터페이스 (계약).
//
// Presentation 계층(Notifier) 은 이 인터페이스만 알면 된다.
// 실제 구현(RecordRepositoryImpl) 은 data 계층에서 만들고,
// Provider 가 둘을 연결한다.
abstract class RecordRepository {
  // 히스토리 한 페이지(=Slice) 를 조회한다.
  // 무한스크롤에서 page 를 1씩 증가시키며 호출.
  Future<RecordSummaryPage> getSummaries({
    required int page,
    int size = 10,
  });

  // 특정 기록의 상세 정보를 조회한다.
  Future<RecordDetail> getDetail(int recordId);

  // 기간 단위 통계를 조회한다.
  // period 는 BE 가 받는 문자열( week/month/year/all ) 그대로.
  Future<RecordStats> getStats(String period);

  // 기록 제목 수정.
  Future<void> changeTitle(int recordId, String title);
}
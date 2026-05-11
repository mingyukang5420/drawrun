import 'package:running/features/record/data/record_remote_datasource.dart';
import 'package:running/features/record/data/record_summary_page.dart';
import 'package:running/features/record/domain/record_detail.dart';
import 'package:running/features/record/domain/record_repository.dart';
import 'package:running/features/record/domain/record_stats.dart';

// RecordRepository 인터페이스 구현체.
//
// 데이터 흐름:
//   Notifier
//     → RecordRepository (인터페이스 — 추상 계약만 안다)
//       → RecordRepositoryImpl (이 클래스)
//         → RecordRemoteDataSource (실제 HTTP 호출)
//
// 이 클래스 자체는 거의 위임만 하지만,
// 분리해 두는 이유는 추후 캐시 / 변환 로직을 끼울 자리가 필요하기 때문.
class RecordRepositoryImpl implements RecordRepository {
  final RecordRemoteDataSource _datasource;

  RecordRepositoryImpl(this._datasource);

  @override
  Future<RecordSummaryPage> getSummaries({
    required int page,
    int size = 10,
  }) {
    return _datasource.fetchSummaries(page: page, size: size);
  }

  @override
  Future<RecordDetail> getDetail(int recordId) {
    return _datasource.fetchDetail(recordId);
  }

  @override
  Future<RecordStats> getStats(String period) {
    return _datasource.fetchStats(period);
  }
}
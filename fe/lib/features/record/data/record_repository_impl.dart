import 'package:running/features/record/data/record_remote_datasource.dart';
import 'package:running/features/record/domain/record_repository.dart';
import 'package:running/features/record/domain/running_record.dart';

// RecordRepository 인터페이스 구현체
// 실제 데이터 흐름: Notifier → RecordRepository → RecordRepositoryImpl → RecordRemoteDataSource
class RecordRepositoryImpl implements RecordRepository {
  final RecordRemoteDataSource _datasource;

  RecordRepositoryImpl(this._datasource);

  @override
  Future<List<RunningRecord>> getRecords() => _datasource.fetchRecords();
}

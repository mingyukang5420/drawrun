import 'package:dio/dio.dart';

import 'package:running/features/record/domain/running_record.dart';
import 'package:running/shared/network/api_exception.dart';

// 기록 관련 HTTP 요청 전담 클래스
// JSON 파싱과 DioException → ApiException 변환을 여기서 처리
class RecordRemoteDataSource {
  final Dio _dio;

  RecordRemoteDataSource(this._dio);

  // GET /records — 전체 러닝 기록 목록 조회
  // TODO: 백엔드 스펙 확정 후 엔드포인트 채움
  Future<List<RunningRecord>> fetchRecords() async {
    try {
      final response = await _dio.get('/records');
      return (response.data as List<dynamic>)
          .map((e) => RunningRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

import 'package:dio/dio.dart';

import 'package:running/shared/network/api_exception.dart';

// HTTP 호출 전담. dio 직접 호출은 이 파일에서만.
// DioException → ApiException 변환 책임.
class RunningRemoteDataSource {
  final Dio _dio;
  RunningRemoteDataSource(this._dio);

  // 러닝 세션 저장.
  // TODO: 백엔드 스펙 확정 후 엔드포인트 채움.
  Future<void> postSession(Map<String, dynamic> body) async {
    try {
      await _dio.post('/api/running/sessions', data: body);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

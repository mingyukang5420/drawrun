import 'package:dio/dio.dart';

import 'package:running/shared/network/api_exception.dart';

// HTTP 호출 전담. dio 직접 호출은 이 파일에서만.
// DioException → ApiException 변환 책임.
class RunningRemoteDataSource {
  final Dio _dio;
  RunningRemoteDataSource(this._dio);

  // 러닝 종료 API 호출.
  Future<void> postSession(Map<String, dynamic> body) async {
    try {
      await _dio.post('/api/v1/run/end', data: body);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // 러닝 시작 — body 의 두 ID 만 전달, 응답 envelope 안의 'result' 객체를 그대로 반환.
  // envelope 벗기기 / 도메인 모델 변환은 Repository 계층의 책임이므로 여기선 Map 까지만.
  Future<Map<String, dynamic>> startRun(Map<String, dynamic> body) async {
    try {
      final response =
      await _dio.post<Map<String, dynamic>>('/api/v1/run/start', data: body);
      final data = response.data;
      if (data == null) {
        // dio 가 200 을 받았지만 body 가 비어있는 상태 — 정상 응답으로 볼 수 없음.
        throw ApiException(statusCode: 200, message: '응답 본문이 비어있음');
      }
      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) {
        // envelope 은 왔는데 result 키 자체가 비어있는 케이스.
        throw ApiException(statusCode: 200, message: '응답 result 가 비어있음');
      }
      return result;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
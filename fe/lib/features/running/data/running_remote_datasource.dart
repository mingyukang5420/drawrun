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

  // 러닝 시작 — 두 ID 를 쿼리 파라미터로 전달, 응답 envelope 안의 'result' 객체를 그대로 반환.
  // envelope 벗기기 / 도메인 모델 변환은 Repository 계층의 책임이므로 여기선 Map 까지만.
  //
  // 백엔드가 @RequestParam(required = false) 두 개로 받는 형태로 바뀌었으므로,
  // null 인 ID 는 쿼리스트링에 키 자체를 넣지 않는다. dio 의 queryParameters 는
  // 값이 null 인 항목을 자동으로 빼주지만, 호출 의도를 코드에 명시해 두는 게 읽기 좋다.
  Future<Map<String, dynamic>> startRun({
    int? courseId,
    int? courseDraftId,
  }) async {
    try {
      // 둘 다 null 이면 자유 러닝 — 빈 Map 으로 호출되어 URL 에 쿼리 자체가 안 붙는다.
      // 한쪽만 not-null 이면 그 키만 쿼리스트링에 실린다.
      final query = <String, dynamic>{
        if (courseId != null) 'courseId': courseId,
        if (courseDraftId != null) 'courseDraftId': courseDraftId,
      };
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/run/start',
        queryParameters: query,
      );
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
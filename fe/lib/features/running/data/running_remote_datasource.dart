import 'package:dio/dio.dart';

import 'package:running/shared/network/api_exception.dart';

// HTTP 호출 전담. dio 직접 호출은 이 파일에서만.
// DioException → ApiException 변환 책임.
class RunningRemoteDataSource {
  final Dio _dio;
  RunningRemoteDataSource(this._dio);

  // 러닝 종료 API 호출.
  // body 형식과 키 이름은 RunningRepositoryImpl._toJson() 이 책임.
  // 이 클래스는 "그 body 를 정확한 엔드포인트로 던진다"만 담당.
  Future<void> postSession(Map<String, dynamic> body) async {
    try {
      await _dio.post('/api/v1/run/end', data: body);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

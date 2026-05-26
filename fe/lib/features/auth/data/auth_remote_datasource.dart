import 'package:dio/dio.dart';

import 'package:running/shared/network/api_exception.dart';

// 인증 관련 HTTP 요청 전담 클래스
// JSON 파싱과 DioException → ApiException 변환을 여기서 처리
class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource(this._dio);

  // POST /api/v1/auth/login — loginId·비밀번호로 로그인 후 서버 발급 토큰 반환
  // 응답 구조: { isSuccess, code, message, result: { accessToken } }
  Future<String> login({
    required String loginId,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/login',
        data: {'loginId': loginId, 'password': password},
      );
      return response.data['result']['accessToken'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // POST /api/v1/auth/logout — 서버 토큰 무효화
  Future<void> logout() async {
    try {
      await _dio.post('/api/v1/auth/logout');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

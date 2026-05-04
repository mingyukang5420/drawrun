import 'package:dio/dio.dart';

import 'package:running/shared/network/api_exception.dart';

// 인증 관련 HTTP 요청 전담 클래스
// JSON 파싱과 DioException → ApiException 변환을 여기서 처리
class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource(this._dio);

  // POST /auth/login — 이메일·비밀번호로 로그인 후 서버 발급 토큰 반환
  // TODO: 백엔드 스펙 확정 후 엔드포인트와 응답 키 수정
  Future<String> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return response.data['token'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // POST /auth/logout — 서버 토큰 무효화
  // TODO: 백엔드 스펙 확정 후 엔드포인트 수정
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

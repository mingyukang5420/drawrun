import 'package:running/features/auth/data/auth_remote_datasource.dart';
import 'package:running/features/auth/domain/auth_repository.dart';
import 'package:running/shared/network/token_storage.dart';

// AuthRepository 인터페이스의 구현체
// 실제 데이터 흐름: ViewModel → AuthRepository(interface) → AuthRepositoryImpl → AuthRemoteDataSource
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _datasource;

  AuthRepositoryImpl(this._datasource);

  @override
  Future<String> login({
    required String loginId,
    required String password,
  }) async {
    final token = await _datasource.login(loginId: loginId, password: password);
    // 로그인 성공 시 토큰을 메모리에 보관 → 이후 요청마다 AuthInterceptor 가 자동 첨부
    TokenStorage.save(token);
    return token;
  }

  @override
  Future<void> logout() async {
    try {
      await _datasource.logout();
    } finally {
      // 서버 오류가 발생해도 로컬 토큰은 반드시 삭제
      TokenStorage.clear();
    }
  }
}

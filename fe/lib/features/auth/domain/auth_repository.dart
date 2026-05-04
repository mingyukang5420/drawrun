// 인증 저장소 추상 인터페이스
// TODO: 백엔드 스펙 확정 후 메서드 구현
abstract class AuthRepository {
  // 이메일·비밀번호로 로그인 후 서버 발급 토큰 반환
  Future<String> login({required String email, required String password});

  // 로그아웃 (서버 토큰 무효화 + 로컬 토큰 삭제)
  Future<void> logout();
}

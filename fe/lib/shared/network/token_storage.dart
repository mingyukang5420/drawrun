// ─────────────────────────────────────────────
// TokenStorage
//
// 로그인 성공 후 서버가 발급한 토큰을 메모리에 보관하는 클래스
//
// [토큰이란?]
// 서버는 로그인에 성공하면 "이 사람은 인증된 사용자"라는 증명서를 발급함
// 이후 요청마다 이 증명서를 함께 보내야 서버가 요청을 허가함
//
// [주의]
// 현재는 앱 메모리에만 저장하므로 앱을 종료하면 토큰이 사라짐
// 실제 서비스에서는 flutter_secure_storage 패키지로 기기에 영구 저장 필요
// ─────────────────────────────────────────────
class TokenStorage {
  // 클래스 전체에서 단 하나만 존재하는 토큰 변수 (static)
  // null 이면 아직 로그인하지 않은 상태
  static String? _token;

  // 로그인 성공 후 서버에서 받은 토큰 저장
  static void save(String token) => _token = token;

  // DioClient 의 인터셉터가 요청마다 읽어가는 토큰 반환
  // 로그인 전이면 null 반환
  static String? read() => _token;

  // 로그아웃 시 토큰 삭제
  static void clear() => _token = null;
}

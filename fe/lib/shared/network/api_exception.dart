import 'package:dio/dio.dart';

// ─────────────────────────────────────────────
// ApiException
//
// API 요청이 실패했을 때 던지는 앱 전용 예외 클래스
//
// [왜 필요한가?]
// Dio 가 오류를 던질 때 DioException 이라는 Dio 전용 형식을 사용함
// 이것을 그대로 쓰면 도메인 코드(Repository, Controller)가
// Dio 라이브러리에 강하게 의존하게 됨
// ApiException 으로 한 번 감싸면 나중에 Dio 를 다른 라이브러리로
// 교체해도 도메인 코드를 수정할 필요가 없음
//
// [사용 흐름]
// Dio 에서 오류 발생
//   → Repository 의 catch 블록에서 ApiException.fromDioException() 호출
//   → Controller 또는 UI 에서 ApiException 을 받아 사용자에게 메시지 표시
// ─────────────────────────────────────────────
class ApiException implements Exception {
  // 서버가 반환한 HTTP 상태 코드
  // 400: 잘못된 요청 / 401: 인증 필요 / 404: 없는 주소 / 500: 서버 오류
  final int statusCode;

  // 사용자에게 보여줄 오류 메시지
  final String message;

  const ApiException({required this.statusCode, required this.message});

  // DioException 을 받아 ApiException 으로 변환하는 팩토리 생성자
  // 팩토리 생성자: 조건에 따라 다른 방식으로 객체를 만들 때 사용하는 생성자
  factory ApiException.fromDioException(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final data = e.response?.data;

    // 네트워크·타임아웃 계열 오류는 서버 응답이 없으므로 유형별로 한국어 메시지 반환
    // (e.message 는 Dio 내부 영문 디버그 문자열이므로 사용자에게 노출하지 않는다)
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return const ApiException(
          statusCode: 0,
          message: '서버에 연결하지 못했습니다. 네트워크를 확인해 주세요.',
        );
      case DioExceptionType.sendTimeout:
        return const ApiException(
          statusCode: 0,
          message: '요청 전송이 너무 오래 걸립니다. 잠시 후 다시 시도해 주세요.',
        );
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          statusCode: 0,
          message: '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해 주세요.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          statusCode: 0,
          message: '네트워크 연결을 확인해 주세요.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          statusCode: 0,
          message: '요청이 취소되었습니다.',
        );
      case DioExceptionType.badResponse:
        // 서버가 응답을 돌려준 경우 — 본문 message 키 또는 상태 코드 기반 메시지 사용
        final serverMessage =
            (data is Map ? data['message'] as String? : null);
        return ApiException(
          statusCode: statusCode,
          message: serverMessage ?? _messageForStatus(statusCode),
        );
      default:
        return const ApiException(
          statusCode: 0,
          message: '알 수 없는 오류가 발생했습니다.',
        );
    }
  }

  // HTTP 상태 코드 → 사용자 안내 문구
  static String _messageForStatus(int code) => switch (code) {
        400 => '잘못된 요청입니다.',
        401 => '인증이 필요합니다. 다시 로그인해 주세요.',
        403 => '접근 권한이 없습니다.',
        404 => '요청한 정보를 찾을 수 없습니다.',
        409 => '이미 존재하는 데이터입니다.',
        500 => '서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        _ => '오류가 발생했습니다. (HTTP $code)',
      };

  // 로그나 디버그 콘솔에서 오류 내용 확인용 문자열 반환
  @override
  String toString() => 'ApiException($statusCode): $message';
}

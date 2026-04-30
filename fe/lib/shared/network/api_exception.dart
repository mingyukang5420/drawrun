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

    // 서버 응답 본문에 'message' 키가 있으면 그 값을 우선 사용
    // 없으면 Dio 자체 메시지, 그것도 없으면 기본 문구로 대체
    final message = (data is Map ? data['message'] as String? : null) ??
        e.message ??
        '알 수 없는 오류 발생';

    return ApiException(statusCode: statusCode, message: message);
  }

  // 로그나 디버그 콘솔에서 오류 내용 확인용 문자열 반환
  @override
  String toString() => 'ApiException($statusCode): $message';
}

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
        // 서버가 응답을 돌려준 경우 — 본문에서 메시지를 추출하거나 상태 코드 기반 메시지 사용
        // 백엔드마다 message/msg/error/detail 등 다른 키를 쓰므로 순서대로 시도
        final serverMessage = _extractServerMessage(data);
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

  // HTTP 상태 코드별 사용자 안내 문구 반환
  //
  // [변경 사항]
  // - 403 메시지를 '접근 권한이 없습니다.' → '요청을 처리할 수 없습니다.' 로 수정
  //   이유: 403은 실제 권한 문제 외에도 파라미터 누락(예: challengeId 미전송) 등
  //         비즈니스 로직 실패에서도 서버가 반환할 수 있음.
  //         이 경우 '접근 권한' 문구는 사용자에게 로그인/권한 문제로 오인시킴.
  // - 401(인증 만료)과 403(요청 거부)을 문구 수준에서 명확히 구분
  static String _messageForStatus(int code) => switch (code) {
        400 => '요청 정보가 올바르지 않습니다.',
        401 => '인증이 필요합니다. 다시 로그인해 주세요.',
        403 => '요청을 처리할 수 없습니다.',
        404 => '요청한 정보를 찾을 수 없습니다.',
        409 => '이미 존재하는 데이터입니다.',
        500 => '서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        _ => '오류가 발생했습니다. (HTTP $code)',
      };

  // 응답 본문에서 사람이 읽을 수 있는 메시지 추출
  //
  // [변경 사항]
  // - 기존: data['message'] 단일 키만 확인 → 누락 시 상태 코드 기반 메시지 사용
  // - 변경: message / msg / error / detail / reason 순서로 시도
  //   이유: 백엔드마다 오류 키 이름이 다를 수 있으며, 서버가 상세 원인을 제공할 때
  //         상태 코드 기반 일반 메시지 대신 실제 원인을 사용자에게 전달
  static String? _extractServerMessage(dynamic data) {
    if (data is! Map) return null;
    for (final key in ['message', 'msg', 'error', 'detail', 'reason']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  // 진짜 인증 오류(세션 만료 · 토큰 없음) 여부 판별
  // 401만 true — 403은 비즈니스 거부이므로 자동 로그아웃 대상이 아님
  bool get isAuthError => statusCode == 401;

  // 디버그·로그 출력용 문자열
  @override
  String toString() => 'ApiException($statusCode): $message';
}

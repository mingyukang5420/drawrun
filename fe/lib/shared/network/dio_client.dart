import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:running/shared/network/token_storage.dart';

// ─────────────────────────────────────────────
// DioClient
//
// 앱 전역에서 공유하는 HTTP 클라이언트 생성 팩토리
//
// [Dio 란?]
// Flutter 에서 서버와 통신(HTTP 요청)할 때 사용하는 라이브러리
// GET(데이터 조회) / POST(데이터 저장) / DELETE(데이터 삭제) 등을 처리함
//
// [인터셉터(Interceptor)란?]
// 모든 요청이 서버로 나가기 전, 또는 응답이 돌아온 후에
// 자동으로 실행되는 중간 처리기
// 예: 모든 요청에 토큰을 자동으로 붙이는 작업
//
// [사용 방법]
// final dio = DioClient.create();        ← 앱 시작 시 1회 생성
// final repo = RunningRepository(dio);   ← 각 Repository 에 주입
// ─────────────────────────────────────────────
class DioClient {
  // 이 클래스는 create() 메서드로만 사용하며 직접 생성 불가
  DioClient._();

  // 인터셉터와 기본 설정이 모두 적용된 Dio 인스턴스 반환
  static Dio create() {
    final dio = Dio(
      BaseOptions(
        // .env 파일의 BASE_URL 값을 서버 주소로 사용
        // 10.0.2.2 는 Android 에뮬레이터에서 개발 PC 의 localhost 를 가리키는 주소
        baseUrl: dotenv.get('BASE_URL', fallback: 'http://10.0.2.2:8080'),

        // 서버에 연결 시도 후 10초 안에 응답 없으면 오류 처리
        connectTimeout: const Duration(seconds: 10),

        // 서버가 응답을 시작한 뒤 10초 안에 완료되지 않으면 오류 처리
        receiveTimeout: const Duration(seconds: 10),

        // 모든 요청의 기본 헤더: JSON 형식으로 데이터를 주고받겠다는 선언
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // 로그인 토큰을 모든 요청 헤더에 자동으로 첨부하는 인터셉터 등록
    dio.interceptors.add(_AuthInterceptor());

    // 디버그 빌드에서만 요청/응답 전체 내용을 콘솔에 출력
    // 배포(release) 빌드에서는 kDebugMode 가 false 이므로 자동으로 비활성화
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }

    return dio;
  }
}

// ─────────────────────────────────────────────
// _AuthInterceptor
//
// 모든 HTTP 요청이 서버로 나가기 직전에 실행되는 인증 인터셉터
// TokenStorage 에 토큰이 있으면 Authorization 헤더에 자동 첨부
//
// [Bearer 토큰이란?]
// "Bearer 토큰값" 형식으로 헤더에 담아 보내는 인증 방식
// 서버는 이 헤더를 보고 요청자가 누구인지 확인함
// ─────────────────────────────────────────────
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = TokenStorage.read();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    // handler.next() 를 호출해야 요청이 실제로 서버로 전송됨
    handler.next(options);
  }
}

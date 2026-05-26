import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/shared/network/dio_client.dart';

// 앱 전역 Dio 인스턴스 Provider
//
// [왜 Provider 로 분리하는가?]
// 기존에는 각 화면의 create: 콜백에서 DioClient.create() 를 직접 호출했다.
// Provider 로 분리하면 의존성 주입 경로가 코드에 명시되고,
// 테스트 시 mock Dio 로 교체할 때 이 파일 한 곳만 수정하면 된다.
//
// autoDispose 를 사용하지 않는 이유:
// HTTP 클라이언트는 앱 생명주기와 함께하는 전역 자원이므로 한 번만 생성한다.
final dioProvider = Provider<Dio>((ref) => DioClient.create());

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/data/record_remote_datasource.dart';
import 'package:running/features/record/data/record_repository_impl.dart';
import 'package:running/features/record/domain/record_repository.dart';
import 'package:running/shared/network/dio_provider.dart';

// 기록 feature 의 Riverpod Provider 모음.
//
// 의존성 흐름:
//   dioProvider          (앱 전역 Dio 인스턴스)
//     ↓
//   recordRemoteDataSourceProvider
//     ↓
//   recordRepositoryProvider     (인터페이스 타입으로 노출)
//     ↓
//   *ViewModelProvider 들
//

// HTTP 데이터소스 Provider — dioProvider 를 watch 해서 같은 Dio 인스턴스를 공유한다.
// 이러면 _AuthInterceptor 가 한 곳에만 붙어도 모든 API 호출에 자동 적용된다.
final recordRemoteDataSourceProvider = Provider<RecordRemoteDataSource>(
      (ref) => RecordRemoteDataSource(ref.watch(dioProvider)),
);

// Repository 구현체 Provider (인터페이스 타입으로 노출).
// Notifier 쪽은 이 인터페이스만 알기 때문에 테스트 시 mock 으로 교체하기 쉽다.
final recordRepositoryProvider = Provider<RecordRepository>(
      (ref) => RecordRepositoryImpl(ref.watch(recordRemoteDataSourceProvider)),
);
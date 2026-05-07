import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/data/running_remote_datasource.dart';
import 'package:running/features/running/data/running_repository_impl.dart';
import 'package:running/features/running/domain/running_repository.dart';
import 'package:running/features/running/presentation/running_viewmodel.dart';
import 'package:running/shared/network/dio_client.dart';
import 'package:running/shared/network/dio_provider.dart';

// RunningNotifier Provider
//
// NotifierProvider.autoDispose: MainTabScreen 이 body: pages[index] 구조이므로
// 탭 전환 시 RunningScreen 이 트리에서 제거된다.
// autoDispose 를 설정하면 화면 제거 시 GPS 구독, 타이머 등이 자동 정리된다.
final runningViewModelProvider =
    NotifierProvider.autoDispose<RunningNotifier, RunningState>(
      _buildRunningNotifier,
);

// HTTP 데이터소스 Provider (테스트 시 mock 으로 교체할 진입점)
final runningRemoteDataSourceProvider = Provider<RunningRemoteDataSource>(
      (ref) => RunningRemoteDataSource(ref.watch(dioProvider)),
);

// Repository 구현체 Provider (인터페이스 타입으로 노출)
final runningRepositoryProvider = Provider<RunningRepository>(
      (ref) => RunningRepositoryImpl(ref.watch(runningRemoteDataSourceProvider)),
);

// NotifierProvider 의 팩토리는 ref 를 받지 못하므로
// course 패턴과 동일하게 DioClient.create() 로 DI 체인을 직접 조립한다
RunningNotifier _buildRunningNotifier() {
  return RunningNotifier(
    RunningRepositoryImpl(RunningRemoteDataSource(DioClient.create())),
  );
}

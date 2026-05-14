import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/data/running_remote_datasource.dart';
import 'package:running/features/running/data/running_repository_impl.dart';
import 'package:running/features/running/data/track_image_remote_datasource.dart';
import 'package:running/features/running/data/track_image_repository_impl.dart';
import 'package:running/features/running/data/weather_remote_datasource.dart';
import 'package:running/features/running/data/weather_repository_impl.dart';
import 'package:running/features/running/domain/running_repository.dart';
import 'package:running/features/running/domain/track_image_repository.dart';
import 'package:running/features/running/domain/weather_repository.dart';
import 'package:running/features/running/presentation/running_viewmodel.dart';
import 'package:running/features/running/presentation/weather_viewmodel.dart';
import 'package:running/shared/network/dio_client.dart';
import 'package:running/shared/network/dio_provider.dart';

// RunningNotifier Provider
//
// autoDispose 를 사용하지 않는다: CountdownScreen → ActiveScreen 전환 시 ref.read만
// 사용하는 구간이 생겨 provider 가 즉시 dispose 되어 GPS 가 멈추는 문제가 발생한다.
// 대신 pause/finish/clear 에서 명시적으로 자원을 정리한다.
final runningViewModelProvider =
    NotifierProvider<RunningNotifier, RunningState>(
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

// 트랙 이미지 업로드용 데이터소스 Provider
// dioProvider 를 공유하므로 인터셉터(인증 토큰 자동 첨부) 도 그대로 적용된다
final trackImageRemoteDataSourceProvider = Provider<TrackImageRemoteDataSource>(
      (ref) => TrackImageRemoteDataSource(ref.watch(dioProvider)),
);

// 트랙 이미지 업로드 Repository Provider (인터페이스 타입으로 노출)
// 화면 코드에서는 이 타입 한 개만 알면 된다
final trackImageRepositoryProvider = Provider<TrackImageRepository>(
      (ref) => TrackImageRepositoryImpl(ref.watch(trackImageRemoteDataSourceProvider)),
);

// 날씨 Repository Provider
final weatherRepositoryProvider = Provider<WeatherRepository>(
  (ref) => WeatherRepositoryImpl(
    WeatherRemoteDataSource(ref.watch(dioProvider)),
  ),
);

// 날씨 상태 Provider
// autoDispose: RunningScreen 이 트리를 떠날 때 자동 해제
final weatherProvider =
    NotifierProvider.autoDispose<WeatherNotifier, WeatherState>(
  () => WeatherNotifier(
    WeatherRepositoryImpl(WeatherRemoteDataSource(DioClient.create())),
  ),
);

// NotifierProvider 의 팩토리는 ref 를 받지 못하므로
// course 패턴과 동일하게 DioClient.create() 로 DI 체인을 직접 조립한다
RunningNotifier _buildRunningNotifier() {
  return RunningNotifier(
    RunningRepositoryImpl(RunningRemoteDataSource(DioClient.create())),
  );
}

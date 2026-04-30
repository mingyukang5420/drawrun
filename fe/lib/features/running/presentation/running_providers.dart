import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';   // ← 3.x 에서 ChangeNotifierProvider 가 여기 있음

import 'package:running/features/running/data/running_remote_datasource.dart';
import 'package:running/features/running/data/running_repository_impl.dart';
import 'package:running/features/running/domain/running_repository.dart';
import 'package:running/features/running/presentation/running_viewmodel.dart';
import 'package:running/shared/network/dio_client.dart';

// 앱 전역 Dio 인스턴스. 한 번만 생성.
final dioProvider = Provider<Dio>((ref) => DioClient.create());

// HTTP 호출 전담
final runningRemoteDataSourceProvider = Provider<RunningRemoteDataSource>(
      (ref) => RunningRemoteDataSource(ref.watch(dioProvider)),
);

// Repository (추상 타입 노출, 내부는 Impl)
final runningRepositoryProvider = Provider<RunningRepository>(
      (ref) => RunningRepositoryImpl(ref.watch(runningRemoteDataSourceProvider)),
);

// ViewModel — Riverpod 이 ChangeNotifier 변경을 감지해 위젯 리빌드
final runningViewModelProvider = ChangeNotifierProvider<RunningViewModel>(
      (ref) => RunningViewModel(repository: ref.watch(runningRepositoryProvider)),
);
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_viewmodel.dart';

// RunningNotifier Provider
//
// NotifierProvider.autoDispose: MainTabScreen 이 body: pages[index] 구조이므로
// 탭 전환 시 RunningScreen 이 트리에서 제거된다.
// autoDispose 를 설정하면 화면 제거 시 GPS 구독, 타이머 등이 자동 정리된다.
final runningViewModelProvider =
    NotifierProvider.autoDispose<RunningNotifier, RunningState>(
  RunningNotifier.new,
);

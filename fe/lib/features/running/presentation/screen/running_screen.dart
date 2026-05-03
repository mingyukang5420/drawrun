import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/widgets/running_map_view.dart';
import 'package:running/shared/map/widgets/map_app_bar.dart';
import 'package:running/shared/map/widgets/map_bottom_panel.dart';
import 'package:running/shared/map/widgets/map_fab.dart';

// 러닝 탭의 메인 화면
// ConsumerWidget: WidgetRef 를 통해 Riverpod Provider 를 구독하는 위젯 기반 클래스
class RunningScreen extends ConsumerWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch: RunningState 가 변경될 때마다 build 를 다시 실행한다
    final state = ref.watch(runningViewModelProvider);

    // ref.read: 콜백에서 Notifier 메서드를 호출할 때 사용 (구독 불필요)
    final notifier = ref.read(runningViewModelProvider.notifier);

    return Scaffold(
      appBar: const MapAppBar(title: '러닝'),

      // 지도 영역
      body: const RunningMapView(),

      // 경로 초기화 버튼 (우하단)
      floatingActionButton: MapFab(onPressed: notifier.clear),

      // 하단 패널: 거리 표시 + 시작/정지 버튼
      bottomNavigationBar: MapBottomPanel(
        distance: state.distanceLabel,
        buttonLabel: state.isRunning ? '정지' : '시작',
        onPressed: state.isRunning ? notifier.finish : notifier.startRunning,
      ),
    );
  }
}

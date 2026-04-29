import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:running/features/running/controller/running_controller.dart';
import 'package:running/features/running/widgets/running_map_view.dart';
import 'package:running/shared/map/widgets/map_app_bar.dart';
import 'package:running/shared/map/widgets/map_bottom_panel.dart';
import 'package:running/shared/map/widgets/map_fab.dart';

// 러닝 탭의 메인 화면
// ChangeNotifierProvider 로 RunningController 를 생성하고,
// 하위 위젯 전체에서 Provider.of / Consumer / context.read 로 접근할 수 있게 한다.
class RunningScreen extends StatelessWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // create 는 화면이 처음 만들어질 때 딱 한 번 호출된다
      create: (_) => RunningController(),
      child: Scaffold(
        appBar: const MapAppBar(title: '러닝'),

        // 지도 영역: RunningController 와 연결된 NaverMap 을 표시한다
        body: const RunningMapView(),

        // 경로 초기화 버튼 (우하단 원형 버튼)
        // Consumer 는 RunningController 가 notifyListeners() 를 호출할 때마다 이 부분만 다시 그린다
        floatingActionButton: Consumer<RunningController>(
          builder: (context, controller, _) {
            return MapFab(onPressed: controller.clear);
          },
        ),

        // 하단 패널: 거리 표시 + 시작/정지 버튼
        bottomNavigationBar: Consumer<RunningController>(
          builder: (context, controller, _) {
            return MapBottomPanel(
              distance: controller.distanceLabel,
              // 러닝 중이면 "정지", 아니면 "시작" 을 표시한다
              buttonLabel: controller.isRunning ? '정지' : '시작',
              onPressed: controller.isRunning
                  ? controller.stopRunning
                  : controller.startRunning,
            );
          },
        ),
      ),
    );
  }
}
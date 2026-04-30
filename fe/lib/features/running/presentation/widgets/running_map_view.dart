import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:running/features/running/presentation/running_viewmodel.dart';
import 'package:running/shared/map/widgets/map_view.dart';

// 러닝 도메인에서 사용하는 지도 위젯.
// 위치 핀 표시 및 카메라 이동은 MapView 에 위임하고,
// 러닝 컨트롤러 등록과 경로 기록만 이 파일에서 담당한다.
class RunningMapView extends StatelessWidget {
  const RunningMapView({super.key});

  @override
  Widget build(BuildContext context) {
    // context.read 는 상태 변화에 반응하지 않는 1회성 읽기다.
    // 콜백 안에서만 presentation 를 사용하므로 여기서는 read 가 적합하다.
    final controller = context.read<RunningController>();

    return MapView(
      // 현재 위치 핀 표시 및 카메라 이동을 MapView 에 요청한다
      showCurrentLocation: true,
      onMapReady: (mapController) {
        // 지도가 준비되면 presentation 에 mapController 를 등록한다.
        // 이후 presentation 가 지도에 경로를 그리거나 지울 수 있다.
        controller.setMapController(mapController);
      },
    );
  }
}

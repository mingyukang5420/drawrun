import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/shared/map/widgets/map_view.dart';

// 러닝 도메인의 지도 위젯.
//
// trackRoute:
//   - true  → 이 지도에 폴리라인을 그린다. setMapController 호출.
//   - false → 위치 핀만 표시. ViewModel 에 controller 를 등록하지 않음.
//
// 메인 RunningScreen 의 지도는 "시작 화면 = 현재 위치만 표시" 역할이라 false.
// 일시정지 시트의 지도는 누적 경로 표시 역할이라 true.
class RunningMapView extends ConsumerStatefulWidget {
  final bool trackRoute;

  const RunningMapView({super.key, this.trackRoute = false});

  @override
  ConsumerState<RunningMapView> createState() => _RunningMapViewState();
}

class _RunningMapViewState extends ConsumerState<RunningMapView> {
  @override
  void dispose() {
    if (widget.trackRoute) {
      // 위젯이 빠지는 시점에 controller 가 무효화되므로
      // ViewModel 에서도 참조를 끊어준다 → 죽은 controller 호출 사고 방지.
      ref
          .read(runningViewModelProvider.notifier)
          .clearMapController();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapView(
      showCurrentLocation: true,
      onMapReady: (mapController) {
        if (widget.trackRoute) {
          ref
              .read(runningViewModelProvider.notifier)
              .setMapController(mapController);
        }
      },
    );
  }
}

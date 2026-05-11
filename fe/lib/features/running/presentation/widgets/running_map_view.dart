import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/running_viewmodel.dart';
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
  // initState 에서 한 번 잡아두고 dispose 에서 안전하게 사용.
  // late final: 처음 한 번만 할당, 그 후 불변.
  late final RunningNotifier _notifier;

  @override
  void initState() {
    super.initState();
    // initState 시점엔 ref 사용 안전.
    // .notifier 를 잡아두면 dispose 시점에 ref 없이도 호출 가능.
    _notifier = ref.read(runningViewModelProvider.notifier);
  }

  @override
  void dispose() {
    // ref 대신 미리 보관해둔 _notifier 사용 → 안전
    _notifier.clearMapController();
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

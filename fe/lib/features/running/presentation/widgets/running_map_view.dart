import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/shared/map/widgets/map_view.dart';

// 러닝 도메인에서 사용하는 지도 위젯
// 위치 핀·카메라 이동은 MapView 에 위임하고,
// Notifier 등록과 경로 기록만 여기서 담당한다
class RunningMapView extends ConsumerWidget {
  const RunningMapView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MapView(
      showCurrentLocation: true,
      onMapReady: (mapController) {
        // ref.read: 지도 준비 콜백은 1회 호출이므로 구독 불필요
        ref
            .read(runningViewModelProvider.notifier)
            .setMapController(mapController);
      },
    );
  }
}

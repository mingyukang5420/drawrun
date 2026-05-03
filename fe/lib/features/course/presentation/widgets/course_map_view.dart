import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/shared/map/widgets/map_view.dart';

// 코스 편집 화면의 지도 위젯
// 위치 핀·카메라 이동은 MapView 에 위임하고,
// Notifier 등록과 경로 점 추가만 이 파일에서 담당
class CourseMapView extends ConsumerWidget {
  const CourseMapView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MapView(
      showCurrentLocation: true,
      onMapReady: (mapController) {
        // ref.read: 콜백은 1회 호출이므로 구독 불필요
        ref
            .read(courseEditorViewModelProvider.notifier)
            .setMapController(mapController);
      },
      onMapTapped: (point, latLng) {
        ref.read(courseEditorViewModelProvider.notifier).addPoint(latLng);
      },
    );
  }
}

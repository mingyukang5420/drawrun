import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/shared/map/widgets/map_view.dart';

// 코스 편집 화면 전용 지도 위젯
// 위치 핀·카메라 이동은 MapView 에 위임하고
// Notifier 컨트롤러 등록과 노드 추가만 이 위젯에서 담당
class CourseEditorMapView extends ConsumerWidget {
  const CourseEditorMapView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MapView(
      // 지도가 열릴 때 현재 위치로 카메라를 이동하고 위치 핀을 표시
      showCurrentLocation: true,
      onMapReady: (mapController) {
        // ref.read: 콜백은 1회 호출이므로 watch 불필요
        ref
            .read(courseEditorProvider.notifier)
            .setMapController(mapController);
      },
      onMapTapped: (point, latLng) {
        // 지도 탭 시 해당 좌표를 노드로 추가
        ref.read(courseEditorProvider.notifier).addNode(latLng);
      },
    );
  }
}

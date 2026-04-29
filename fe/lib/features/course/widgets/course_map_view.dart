import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:running/features/course/controller/course_controller.dart';
import 'package:running/shared/map/widgets/map_view.dart';

// 코스 도메인에서 사용하는 지도 위젯.
// 위치 핀 표시 및 카메라 이동은 MapView 에 위임하고,
// 코스 컨트롤러 등록과 경로 점 추가만 이 파일에서 담당한다.
class CourseMapView extends StatelessWidget {
  const CourseMapView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CourseController>();

    return MapView(
      // 현재 위치 핀 표시 및 카메라 이동을 MapView 에 요청한다
      showCurrentLocation: true,
      onMapReady: (mapController) {
        controller.setMapController(mapController);
      },
      onMapTapped: (point, latLng) {
        controller.addPoint(latLng);
      },
    );
  }
}

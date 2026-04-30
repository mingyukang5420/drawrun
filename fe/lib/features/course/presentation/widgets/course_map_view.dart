import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:running/features/course/presentation/course_viewmodel.dart';
import 'package:running/shared/map/widgets/map_view.dart';

// 코스 편집 화면의 지도 위젯
// 위치 핀 표시와 카메라 이동은 MapView 에 위임하고
// ViewModel 등록과 경로 점 추가만 이 파일에서 담당
class CourseMapView extends StatelessWidget {
  const CourseMapView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<CourseViewModel>();

    return MapView(
      showCurrentLocation: true,
      onMapReady: (mapController) {
        vm.setMapController(mapController);
      },
      onMapTapped: (point, latLng) {
        vm.addPoint(latLng);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

import 'package:running/features/course/controller/course_controller.dart';
import 'package:running/shared/location/location_service.dart';
import 'package:running/shared/map/widgets/map_view.dart';

class CourseMapView extends StatelessWidget {
  const CourseMapView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CourseController>();

    return MapView(
      onMapReady: (mapController) async {
        controller.setMapController(mapController);

        // 현재 위치를 가져와 카메라를 이동한다.
        // 위치를 가져올 수 없으면 MapView 의 기본 위치(서울 시청)를 그대로 사용한다.
        final position = await LocationService.getCurrentPosition();
        if (position != null) {
          await mapController.updateCamera(
            NCameraUpdate.scrollAndZoomTo(
              target: NLatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          );
        }
      },
      onMapTapped: (point, latLng) {
        controller.addPoint(latLng);
      },
    );
  }
}

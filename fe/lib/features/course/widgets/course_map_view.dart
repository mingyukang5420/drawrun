import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

import 'package:running/features/course/controller/course_controller.dart';

class CourseMapView extends StatelessWidget {
  const CourseMapView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CourseController>();

    return NaverMap(
      onMapReady: (mapController) {
        controller.setMapController(mapController);
      },
      onMapTapped: (point, latLng) {
        controller.addPoint(latLng);
      },
      options: const NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(37.5665, 126.9780),
          zoom: 14,
        ),
      ),
    );
  }
}
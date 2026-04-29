import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class CourseController extends ChangeNotifier {
  final List<NLatLng> points = [];

  NPolylineOverlay? routeLine;
  NaverMapController? mapController;

  void setMapController(NaverMapController controller) {
    mapController = controller;
  }

  void addPoint(NLatLng point) {
    points.add(point);
    drawRoute();
    notifyListeners();
  }

  void clear() {
    if (mapController == null) return;

    if (routeLine != null) {
      mapController!.deleteOverlay(routeLine!.info);
      routeLine = null;
    }

    points.clear();
    notifyListeners();
  }

  void drawRoute() {
    if (mapController == null) return;

    if (routeLine != null) {
      mapController!.deleteOverlay(routeLine!.info);
    }

    routeLine = NPolylineOverlay(
      id: 'route',
      coords: points,
      width: 6,
    );

    mapController!.addOverlay(routeLine!);
  }
}
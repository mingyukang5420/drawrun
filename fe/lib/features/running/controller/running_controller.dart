import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

// 러닝 도메인의 상태와 로직을 관리하는 컨트롤러
// ChangeNotifier 를 상속하면 notifyListeners() 호출 시 Consumer 위젯이 자동으로 다시 그려진다.
class RunningController extends ChangeNotifier {
  // 현재 러닝 중인지 여부
  bool isRunning = false;

  // 누적 이동 거리 (km 단위)
  double distanceKm = 0.0;

  // 지도에 찍힌 좌표 목록 (경로를 구성하는 점들)
  final List<NLatLng> points = [];

  // 지도 위에 그려진 경로 선 오버레이 (null 이면 아직 그려지지 않은 상태)
  NPolylineOverlay? routeLine;

  // 지도를 직접 제어하는 객체. onMapReady 콜백에서 등록된다.
  NaverMapController? mapController;

  // 지도가 준비된 뒤 RunningMapView 에서 호출한다
  void setMapController(NaverMapController controller) {
    mapController = controller;
  }

  void startRunning() {
    isRunning = true;
    notifyListeners();
  }

  void stopRunning() {
    isRunning = false;
    notifyListeners();
  }

  // 새 좌표를 경로에 추가한다. 러닝 중이 아니면 무시한다
  void addPoint(NLatLng point) {
    if (!isRunning) return;

    // 이전 점이 있으면 두 점 사이의 거리를 누적한다
    if (points.isNotEmpty) {
      distanceKm += _haversineKm(points.last, point);
    }

    points.add(point);
    _drawRoute();
    notifyListeners();
  }

  // 경로와 상태를 모두 초기화한다
  void clear() {
    if (mapController != null && routeLine != null) {
      mapController!.deleteOverlay(routeLine!.info);
      routeLine = null;
    }
    points.clear();
    distanceKm = 0.0;
    isRunning = false;
    notifyListeners();
  }

  // points 목록을 바탕으로 지도에 경로 선을 다시 그린다
  void _drawRoute() {
    // 점이 2개 미만이면 선을 그릴 수 없다
    if (mapController == null || points.length < 2) return;

    // 기존 경로 선을 먼저 지운다 (덮어쓰기 방지)
    if (routeLine != null) {
      mapController!.deleteOverlay(routeLine!.info);
    }

    routeLine = NPolylineOverlay(
      id: 'running_route',
      coords: points,
      width: 6,
    );

    mapController!.addOverlay(routeLine!);
  }

  // 두 GPS 좌표 사이의 거리를 km 단위로 반환한다 (Haversine 공식)
  // 지구 곡률을 고려한 구면 거리 계산 방식으로, GPS 거리 측정에 표준적으로 사용된다.
  double _haversineKm(NLatLng a, NLatLng b) {
    const r = 6371.0; // 지구 반지름 (km)
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.latitude)) *
            cos(_toRad(b.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * asin(sqrt(h));
  }

  double _toRad(double deg) => deg * pi / 180;

  // UI 에서 바로 사용할 수 있는 거리 문자열 (예: "1.23 km")
  String get distanceLabel => '${distanceKm.toStringAsFixed(2)} km';
}

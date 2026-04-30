import 'dart:math';
import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:running/shared/location/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:running/shared/map/lat_lng_naver_ext.dart';

import '../../../shared/model/lat_lng.dart';

// 러닝 도메인의 상태와 로직을 관리하는 컨트롤러
// ChangeNotifier 를 상속하면 notifyListeners() 호출 시 Consumer 위젯이 자동으로 다시 그려진다.
class RunningViewModel extends ChangeNotifier {
  // 현재 러닝 중인지 여부
  bool isRunning = false;

  // 누적 이동 거리 (km 단위)
  double distanceKm = 0.0;

  // 지도에 찍힌 좌표 목록 (경로를 구성하는 점들)
  final List<LatLng> points = [];

  // 지도 위에 그려진 경로 선 오버레이 (null 이면 아직 그려지지 않은 상태)
  NPolylineOverlay? routeLine;

  // 지도를 직접 제어하는 객체. onMapReady 콜백에서 등록된다.
  NaverMapController? mapController;

  // GPS 스트림 구독
  // 시작 전/정지 후엔 null - null 여부로 구독 활성 상태 판별
  StreamSubscription<LatLng>? _locationSub;

  // 지도가 준비된 뒤 RunningMapView 에서 호출한다
  void setMapController(NaverMapController controller) {
    mapController = controller;
  }

  void startRunning() {
    // 이미 GPS 스트림이 구독되어 있는지 판단
    // 중복좌표 예방
    if(_locationSub != null) return;
    isRunning = true;

    // GPS 스트림 구독 시작
    // distanceFilter가 5 이므로 5m 이상 이동했을 경우에 좌표 저장
    _locationSub = LocationService.getLatLngStream().listen(addPoint);
    notifyListeners();
  }

  Future<void> stopRunning() async {
    isRunning = false;

    // GPS 스트림 구독 취소
    // cancel()은 Future을 반환하므로 await으로 정리가 끝난 뒤 null로 되돌림
    await _locationSub?.cancel();
    _locationSub = null;
    notifyListeners();
  }

  // 새 좌표를 경로에 추가한다. 러닝 중이 아니면 무시한다
  void addPoint(LatLng point) {
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
  Future<void> clear() async {
    // GPS 스트림 구독 먼저 취소
    // 해당 로직이 없으면 초기화 버튼을 누르자마자 새 좌표가 들어옴
    await _locationSub?.cancel();
    _locationSub = null;

    // 지도에서 폴리라인 오버레이 제거
    if (mapController != null && routeLine != null) {
      mapController!.deleteOverlay(routeLine!.info);
      routeLine = null;
    }

    // 메모리 상태도 함께 초기화
    points.clear();
    distanceKm = 0.0;
    isRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _locationSub = null;
    super.dispose();
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
      coords: points.map((p) => p.toNLatLng()).toList(),
      width: 6,
      color: Colors.blueAccent,
    );

    mapController!.addOverlay(routeLine!);
  }

  // 두 GPS 좌표 사이의 거리를 km 단위로 반환한다 (Haversine 공식)
  // 지구 곡률을 고려한 구면 거리 계산 방식으로, GPS 거리 측정에 표준적으로 사용된다.
  double _haversineKm(LatLng a, LatLng b) {
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

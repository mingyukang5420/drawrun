import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import 'package:running/shared/location/location_service.dart';

// shared/map 의 공통 지도 위젯.
// 각 도메인(러닝, 코스 등)은 onMapReady / onMapTapped 콜백을 주입해서 사용한다.
// showCurrentLocation 을 true 로 설정하면 현재 위치 핀이 실시간으로 표시된다.
class MapView extends StatefulWidget {
  // 지도가 준비됐을 때 호출되며, NaverMapController 를 받아 외부에서 지도를 제어할 수 있다
  final void Function(NaverMapController)? onMapReady;

  // 사용자가 지도를 탭했을 때 호출된다
  final void Function(NPoint, NLatLng)? onMapTapped;

  // true 이면 현재 위치로 카메라를 이동하고 실시간 위치 핀을 표시한다
  final bool showCurrentLocation;

  const MapView({
    super.key,
    this.onMapReady,
    this.onMapTapped,
    this.showCurrentLocation = false,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  // 위치 스트림 구독 객체. dispose 시 반드시 취소해야 메모리 누수가 발생하지 않는다.
  StreamSubscription<Position>? _locationSubscription;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  // 현재 위치로 카메라를 이동하고, 위치 오버레이(핀)를 켜서 실시간으로 갱신한다.
  Future<void> _setupLocationOverlay(NaverMapController mapController) async {
    final position = await LocationService.getCurrentPosition();
    if (position == null) return;

    // 현재 위치로 카메라를 이동한다
    await mapController.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(position.latitude, position.longitude),
        zoom: 15,
      ),
    );

    // 네이버 지도 내장 위치 핀(파란 점)을 가져와서 표시한다
    // getLocationOverlay 는 Future 가 아니므로 await 불필요
    final locationOverlay = mapController.getLocationOverlay();
    locationOverlay.setIsVisible(true);
    locationOverlay.setPosition(
      NLatLng(position.latitude, position.longitude),
    );

    // GPS 위치가 변경될 때마다 핀 위치를 갱신한다
    _locationSubscription = LocationService.getPositionStream().listen((pos) {
      locationOverlay.setPosition(NLatLng(pos.latitude, pos.longitude));
    });
  }

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      // 서울 시청을 기본 중심 좌표로 사용한다 (현재 위치를 가져오기 전 잠깐 표시된다)
      options: const NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(37.5665, 126.9780),
          zoom: 14,
        ),
      ),
      onMapReady: (mapController) async {
        // showCurrentLocation 이 true 면 위치 핀 설정을 먼저 수행한다
        if (widget.showCurrentLocation) {
          await _setupLocationOverlay(mapController);
        }
        // 그 다음 도메인별 콜백(컨트롤러 등록 등)을 실행한다
        widget.onMapReady?.call(mapController);
      },
      onMapTapped: widget.onMapTapped,
    );
  }
}

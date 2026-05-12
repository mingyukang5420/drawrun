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

  // 카메라 이동이 완전히 멈춘 후 호출된다 (스크롤·줌 조작 종료 시점)
  final VoidCallback? onCameraIdle;

  // 위치 권한 거부·GPS 꺼짐 등으로 현재 위치를 가져오지 못했을 때 호출된다
  final VoidCallback? onLocationError;

  const MapView({
    super.key,
    this.onMapReady,
    this.onMapTapped,
    this.showCurrentLocation = false,
    this.onCameraIdle,
    this.onLocationError,
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
    if (position == null) {
      // 위치 권한 거부 또는 GPS 꺼짐 → 서울 중심부 전체가 보이는 줌으로 고정
      await mapController.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: const NLatLng(37.5665, 126.9780),
          zoom: 11,
        ),
      );
      widget.onLocationError?.call();
      return;
    }

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
        // 컨트롤러 등록을 먼저 수행해야 이후 카메라 이동으로 발생하는
        // onCameraIdle 이벤트를 notifier 가 정상적으로 처리할 수 있다
        widget.onMapReady?.call(mapController);
        // 컨트롤러 등록 후 위치 이동 → 이동 완료 시 onCameraIdle 이 발생하고
        // notifier 가 해당 시점의 도로 데이터를 로드한다
        if (widget.showCurrentLocation) {
          await _setupLocationOverlay(mapController);
        }
      },
      onMapTapped: widget.onMapTapped,
      // 카메라가 멈추면 외부 콜백을 실행한다 (도로 데이터 갱신 등에 활용)
      onCameraIdle: widget.onCameraIdle,
    );
  }
}

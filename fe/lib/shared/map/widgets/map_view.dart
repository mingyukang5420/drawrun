import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

// shared/map 의 공통 지도 위젯.
// 각 도메인(러닝, 코스 등)은 onMapReady / onMapTapped 콜백을 주입해서 사용한다.
class MapView extends StatelessWidget {
  // 지도가 준비됐을 때 호출되며, NaverMapController 를 받아 외부에서 지도를 제어할 수 있다
  final void Function(NaverMapController)? onMapReady;

  // 사용자가 지도를 탭했을 때 호출된다
  final void Function(NPoint, NLatLng)? onMapTapped;

  const MapView({
    super.key,
    this.onMapReady,
    this.onMapTapped,
  });

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      // 서울 시청을 기본 중심 좌표로 사용한다
      options: const NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(37.5665, 126.9780),
          zoom: 14,
        ),
      ),
      onMapReady: onMapReady,
      onMapTapped: onMapTapped,
    );
  }
}

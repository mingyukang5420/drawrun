import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'package:running/shared/map/lat_lng_naver_ext.dart';
import 'package:running/shared/model/lat_lng.dart';

// 상세 화면의 "상세 경로 보기" 버튼으로 진입하는 풀스크린 지도.
//
// 책임:
//   1) 받은 nodes 좌표 리스트를 폴리라인으로 그린다.
//   2) 시작점(녹색) / 끝점(주황) 을 원형 마커로 표시한다.
//   3) 카메라를 polyline 전체가 보이도록 fitBounds.
//   4) 그 외 모든 제스처(패닝/줌/회전) 는 NaverMap 의 기본 동작에 맡긴다.
//
// 별도 Notifier 가 필요 없는 이유:
//   - 받은 nodes 는 불변.
//   - 화면 상태는 "지도가 준비됐는지" 한 가지 뿐인데, 그것조차 NaverMap 의 onMapReady
//     콜백에서 한 번 처리하고 끝나므로 외부 state 가 필요 없다.
class RecordRouteScreen extends StatefulWidget {
  // 상세 화면에서 받은 경로 좌표.
  // 새 BE 호출 없이 상세 화면이 이미 가지고 있는 값을 그대로 넘겨 받는다.
  final List<LatLng> nodes;

  // AppBar 제목으로 표시할 러닝 제목.
  // null/빈 문자열이면 기본 "상세 경로" 로 표기.
  final String title;

  const RecordRouteScreen({
    super.key,
    required this.nodes,
    required this.title,
  });

  @override
  State<RecordRouteScreen> createState() => _RecordRouteScreenState();
}

class _RecordRouteScreenState extends State<RecordRouteScreen> {
  // 동일한 컨트롤러를 onMapReady 이후 다른 콜백에서 쓸 일은 없지만,
  // 추후 "내 위치로 이동" 같은 버튼이 들어오면 여기에 보관한 컨트롤러를 사용한다.
  // 현재로썬 단순 보관용.
  NaverMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar 는 지도 위에 떠 있는 일반적인 헤더로 처리.
      // extendBodyBehindAppBar 를 켜면 지도가 AppBar 영역까지 그려져 화면이 시원하다.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // AppBar 배경을 살짝 반투명하게 — 지도와 자연스럽게 어우러진다.
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          widget.title.isEmpty ? '상세 경로' : widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: NaverMap(
        // 초기 카메라 — 한국 중부쯤. onMapReady 안에서 곧 fitBounds 로 옮긴다.
        // 좌표가 부족해 fitBounds 가 호출되지 않더라도, 사용자는 검정 화면이 아닌
        // 한국 지도를 보게 되어 덜 어색하다.
        options: const NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: NLatLng(36.5, 127.8),
            zoom: 6,
          ),
          // 사용자가 자유롭게 패닝·줌·회전할 수 있도록 모든 제스처를 켠다.
          // (네이버 맵 SDK 기본값이 true 이지만 의도를 분명히 하기 위해 명시적으로 둔다.)
          scrollGesturesEnable: true,
          zoomGesturesEnable: true,
          rotationGesturesEnable: true,
          tiltGesturesEnable: true,
        ),
        onMapReady: _onMapReady,
      ),
    );
  }

  // 지도 컨트롤러 준비 → 폴리라인 + 마커 + fitBounds 일괄 실행.
  Future<void> _onMapReady(NaverMapController controller) async {
    _controller = controller;

    // domain LatLng → flutter_naver_map NLatLng 변환.
    // shared/map/lat_lng_naver_ext.dart 의 .toNLatLng() 사용.
    final coords = widget.nodes.map((p) => p.toNLatLng()).toList();

    // 좌표가 2점 미만이면 선/시작/끝 개념이 의미 없다 — 아무것도 안 그리고 카메라도 안 옮긴다.
    // 사용자에게는 빈 한국 지도가 보이게 되지만 이건 BE 데이터 이상 상황이라 별도 처리 X.
    if (coords.length < 2) return;

    // ── 폴리라인 ─────────────────────────────────────────────
    // 시안의 주황 두꺼운 선과 비슷한 두께.
    await controller.addOverlay(NPolylineOverlay(
      id: 'route_polyline',
      coords: coords,
      width: 6,
      color: const Color(0xFFFF6B35),
    ));

    // ── 시작/끝 마커 ─────────────────────────────────────────
    // NCircleOverlay 가 단순 점 표시에 적합 — 별도 아이콘 자원 필요 없음.
    // radius 단위는 미터(m) — zoom 에 따라 크기가 같이 변한다.
    // 폴리라인(width: 6px) 을 가리지 않도록 작게 둔다. 도심 구간에선 2m 가 적당.
    await controller.addOverlay(NCircleOverlay(
      id: 'route_start',
      center: coords.first,
      radius: 2,
      color: const Color(0xFF27AE60), // 시작 = 녹색
    ));
    await controller.addOverlay(NCircleOverlay(
      id: 'route_end',
      center: coords.last,
      radius: 2,
      color: const Color(0xFFFF6B35), // 끝 = 주황
    ));

    // ── 카메라 fitBounds ───────────────────────────────────────
    // 폴리라인 전체가 화면 안에 들어오도록 카메라를 한 번 맞춘다.
    // 그 다음부터는 사용자가 자유롭게 조작 가능.
    final bounds = NLatLngBounds.from(coords);
    final update = NCameraUpdate.fitBounds(
      bounds,
      padding: const EdgeInsets.all(60),
    );
    // 진입 직후라 부드러운 애니메이션 대신 즉시 이동이 자연스럽다.
    update.setAnimation(animation: NCameraAnimation.none);
    await controller.updateCamera(update);
  }
}
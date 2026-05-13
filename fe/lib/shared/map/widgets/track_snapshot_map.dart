import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'package:running/shared/map/lat_lng_naver_ext.dart';
import 'package:running/shared/model/lat_lng.dart';

// 좌표 리스트를 받아 NaverMap 위에 폴리라인을 그리고,
// 카메라가 settle 되면 PNG 스냅샷 한 장을 만들어 콜백으로 돌려주는 공용 위젯.
//
// 도메인(러닝/에디터 등) 별로 다른 정책은 이 위젯이 관여하지 않는다. 캡처가 끝난 PNG File 을 부모에게 한 번 넘겨주고
// 거기서부터는 호출자의 몫.
//
// 호출자가 Future 형태로 받고 싶다면 Completer<File> 로 콜백을 감싸 사용한다.
class TrackSnapshotMap extends StatefulWidget {
  // 지도 위에 폴리라인으로 그릴 좌표들.
  // 2개 미만이면 폴리라인을 그리지 않고 빈 지도 위에서 캡처가 진행된다.
  final List<LatLng> nodes;

  // 캡처가 성공해 PNG File 이 만들어졌을 때 한 번 호출된다.
  // 같은 위젯 인스턴스에서 두 번 호출되는 일은 없다.
  final ValueChanged<File> onCaptured;

  // 캡처 도중 예외가 발생했을 때 한 번 호출된다.
  // 일반적으로 try/catch 의 catch 블록에 실린 객체가 그대로 전달된다.
  final ValueChanged<Object> onCaptureFailed;

  // 폴리라인 색. 기본은 러닝 도메인 기준 파란 계열.
  // 에디터 등 다른 도메인에서 다른 톤이 필요하면 호출자가 지정.
  final Color polylineColor;

  // 폴리라인 굵기.
  final double polylineWidth;

  // fitBounds 적용 시 좌표 사각형 주위에 둘 여백.
  // 0 이면 폴리라인이 화면 끝에 딱 붙어 잘림 — 기본값은 약간 넉넉히.
  final EdgeInsets fitPadding;

  // takeSnapshot 의 PNG 압축 품질 (0~100).
  // 기본값은 기존 러닝 결과 화면이 쓰던 80 을 유지.
  final int compressQuality;

  // 캡처 직전 한 프레임을 더 대기할 시간.
  // onMapLoaded 신호가 와도 GPU 가 그린 결과가 캡처 버퍼에 반영되기까지 약간의 지연이 있다.
  // 기본 100ms 면 대부분 안정적이지만, 디바이스/지도 복잡도에 따라 호출자가 조정 가능.
  final Duration captureDelay;

  const TrackSnapshotMap({
    super.key,
    required this.nodes,
    required this.onCaptured,
    required this.onCaptureFailed,
    this.polylineColor = Colors.blueAccent,
    this.polylineWidth = 6,
    this.fitPadding = const EdgeInsets.all(40),
    this.compressQuality = 80,
    this.captureDelay = const Duration(milliseconds: 100),
  });

  @override
  State<TrackSnapshotMap> createState() => _TrackSnapshotMapState();
}

class _TrackSnapshotMapState extends State<TrackSnapshotMap> {
  // onMapReady 에서 받은 컨트롤러를 다른 콜백에서도 쓰기 위해 보관.
  NaverMapController? _controller;

  // fitBounds 로 인한 카메라 이동이 적어도 한 번 끝났다는 표시.
  // 이 플래그가 false 인 동안 onMapLoaded 가 와도 캡처를 시작하지 않는다.
  // 초기 카메라 위치 기준의 onMapLoaded 한 번이 잘못 캡처되는 사고를 막기 위함.
  bool _cameraSettled = false;

  // 위젯 생애 동안 단 한 번만 캡처를 진행하기 위한 가드.
  bool _snapshotTriggered = false;

  @override
  Widget build(BuildContext context) {
    final nodes = widget.nodes;

    return NaverMap(
      // 폴리라인이 어디에 있든 일단 한국 중부쯤을 초기값으로 둔다.
      // onMapReady 안에서 곧장 fitBounds 로 다시 맞추므로 사용자에겐 안 보인다.
      options: const NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(36.5, 127.8),
          zoom: 6,
        ),
      ),

      onMapReady: (controller) async {
        _controller = controller;

        // 좌표가 너무 적으면(0–1 점) fitBounds 가 의미가 없다.
        // 빈 지도라도 한 장은 찍을 수 있도록 카메라 이동 없이 곧장 settle 표시만 켠다.
        // 그러면 다음에 들어올 onMapLoaded 가 첫(유일) 캡처 신호가 된다.
        if (nodes.length < 2) {
          _cameraSettled = true;
          return;
        }

        // 폴리라인 그리기.
        final overlay = NPolylineOverlay(
          id: 'track_snapshot_route',
          coords: nodes.map((p) => p.toNLatLng()).toList(),
          width: widget.polylineWidth,
          color: widget.polylineColor,
        );
        await controller.addOverlay(overlay);

        // 카메라를 폴리라인 전체가 들어오도록 맞추기.
        // NLatLngBounds.from 은 좌표 리스트로부터 (남서/북동) 사각형을 자동 계산.
        final bounds = NLatLngBounds.from(nodes.map((p) => p.toNLatLng()));

        final cameraUpdate = NCameraUpdate.fitBounds(
          bounds,
          padding: widget.fitPadding,
        );
        // 애니메이션 없이 즉시 이동 — 캡처 타이밍을 단순하게 만든다.
        cameraUpdate.setAnimation(animation: NCameraAnimation.none);
        await controller.updateCamera(cameraUpdate);
        // updateCamera 가 await 으로 풀려도 곧장 캡처하지 않는다.
        // onCameraIdle → onMapLoaded 신호를 기다려야 타일이 다 그려진 화면을 잡을 수 있다.
      },

      onCameraIdle: () {
        // fitBounds 로 인한 카메라 이동이 멈춘 시점.
        // 이제부터 들어오는 onMapLoaded 는 "새 영역의 타일까지 다 그려졌다" 는 의미.
        _cameraSettled = true;
      },

      onMapLoaded: () async {
        // 카메라가 멈춘 뒤(_cameraSettled=true) 들어온 신호여야만 캡처를 시작한다.
        // 그렇지 않으면 초기 카메라 위치(한국 중부) 화면이 그대로 캡처되는 사고가 난다.
        if (!_cameraSettled) return;
        if (_snapshotTriggered) return;
        if (_controller == null) return;
        _snapshotTriggered = true;

        // 타일은 그려졌지만 GPU 반영을 위해 한 프레임 양보.
        await Future<void>.delayed(widget.captureDelay);

        await _capture(_controller!);
      },
    );
  }

  // takeSnapshot 호출 → PNG File 을 콜백으로 전달.
  // 실패 시 onCaptureFailed 로 예외 객체 전달.
  // 어느 쪽이든 위젯이 트리에서 빠진 뒤에는 콜백을 부르지 않는다 — setState 사고 방지.
  Future<void> _capture(NaverMapController controller) async {
    try {
      final File file =
      await controller.takeSnapshot(compressQuality: widget.compressQuality);
      if (!mounted) return;
      widget.onCaptured(file);
    } catch (e) {
      if (!mounted) return;
      widget.onCaptureFailed(e);
    }
  }
}
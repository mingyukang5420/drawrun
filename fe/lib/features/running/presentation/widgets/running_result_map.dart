import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/shared/map/lat_lng_naver_ext.dart';

// 결과 화면 카드 안에 들어가는 "코스만 보여주는" 정적 지도.
//
// 이 위젯이 하는 일:
//  1. 지도가 준비되면 사용자가 뛴 경로(state.points)를 폴리라인으로 그린다
//  2. 그 경로 전체가 화면에 들어오도록 NCameraUpdate.fitBounds 로 카메라를 맞춘다
//  3. 카메라가 settle 된 다음 takeSnapshot 으로 PNG 파일을 만든다
//  4. 그 PNG 파일을 사용자 사진첩(갤러리)에 저장한다 — 서버 업로드는 다음 단계
//
// 한 번만 진행되도록 _snapshotTriggered 로 가드한다.
// 현재 이미지 전송 API가 결정되지 않아 임시로 사진첩에 저장하며,
// gal 의존성 및 안드로이드 사진첩 접근 권한 또한 추후에 제거 예정
class RunningResultMap extends ConsumerStatefulWidget {
  const RunningResultMap({super.key});

  @override
  ConsumerState<RunningResultMap> createState() => _RunningResultMapState();
}

class _RunningResultMapState extends ConsumerState<RunningResultMap> {
  // onMapReady 에서 받은 컨트롤러를 보관해 다른 콜백에서도 쓴다.
  NaverMapController? _controller;

  // fitBounds 로 인한 카메라 이동이 적어도 한 번 끝났다는 표시.
  // 이 플래그가 false 인 동안 onMapLoaded 가 와도 캡처를 시작하지 않는다.
  // (초기 카메라 위치 기준의 onMapLoaded 한 번이 잘못 캡처되는 걸 막기 위함)
  bool _cameraSettled = false;

  // 위젯 생애 동안 단 한 번만 캡처를 진행하기 위한 플래그.
  bool _snapshotTriggered = false;

  @override
  Widget build(BuildContext context) {
    // finish() 직전 상태 그대로 — 결과 화면에선 새로 점이 추가되지 않으므로 watch 불필요.
    final points = ref.read(runningViewModelProvider).points;

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
        if (points.length < 2) {
          // 빈 지도라도 한 장은 찍어 사진첩에 저장한다 (정책: 모든 러닝 후 한 장).
          // 이 경로에서는 카메라 이동이 없으므로 _cameraSettled 를 곧장 켠다.
          _cameraSettled = true;
          // 그리고 onMapLoaded 가 첫 번째 (= 유일한) 타일 로딩 신호다.
          // onMapLoaded 콜백에서 _captureAndSave 가 한 번 발사된다.
          return;
        }

        // 1) 폴리라인 그리기 ────────────────────────────────────────
        final overlay = NPolylineOverlay(
          id: 'running_result_route',
          coords: points.map((p) => p.toNLatLng()).toList(),
          width: 6,
          color: Colors.blueAccent,
        );
        await controller.addOverlay(overlay);

        // 2) 카메라를 폴리라인 전체가 들어오도록 맞추기 ────────────
        // NLatLngBounds.from 은 좌표 리스트로부터 (남서/북동) 사각형을 자동 계산해 준다.
        final bounds =
        NLatLngBounds.from(points.map((p) => p.toNLatLng()));

        // padding 을 주는 이유:
        //   bounds 그대로 fitBounds 하면 폴리라인이 화면 가장자리에 딱 붙어 잘려 보인다.
        //   상하좌우로 적당한 여백을 두면 미관도 좋고, 잘림도 막는다.
        final cameraUpdate = NCameraUpdate.fitBounds(
          bounds,
          padding: const EdgeInsets.all(40),
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
        // 안 그러면 초기 카메라 위치(한국 중부) 화면이 그대로 캡처되는 사고가 난다.
        if (!_cameraSettled) return;
        if (_snapshotTriggered) return;
        if (_controller == null) return;
        _snapshotTriggered = true;

        // onMapLoaded 가 호출됐다 = 타일은 이미 화면에 그려졌다.
        // 다만 한 프레임 더 양보해 주면 GPU 가 그린 결과가 캡처 버퍼에 반영된 뒤 잡힌다.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await _captureAndSave(_controller!);
      },
    );
  }

  // 스냅샷 찍어서 사진첩에 저장하는 단일 책임 헬퍼.
  Future<void> _captureAndSave(NaverMapController controller) async {
    try {
      // takeSnapshot 은 PNG 임시 파일을 디스크에 쓰고 그 File 을 돌려준다.
      // compressQuality 80 = 용량/품질 적당한 기본값.
      final File file = await controller.takeSnapshot(compressQuality: 80);

      // 사용자가 사진첩 접근을 한 번도 허용하지 않았다면 권한 요청.
      // 이미 허용된 적 있으면 즉시 true 반환.
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) return;

      // 파일 경로를 그대로 사진첩으로 복사.
      // album 인자에 폴더명을 지정하면 iOS 사진첩에 별도 앨범, Android 갤러리에 별도 폴더로 묶인다.
      await Gal.putImage(file.path, album: '러닝');
    } catch (_) {
      // 스냅샷 실패는 본 저장 흐름과 무관 — UI 도 건드리지 않는다.
    }
  }
}
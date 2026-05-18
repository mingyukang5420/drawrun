import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/running_viewmodel.dart';
import 'package:running/shared/map/widgets/map_view.dart';

// 러닝 도메인의 지도 위젯.
//
// trackRoute:
//   - true  → 이 지도에 폴리라인을 그린다. setMapController 호출.
//   - false → 위치 핀만 표시. ViewModel 에 controller 를 등록하지 않음.
//
// contentPadding:
//   - null (미명시) — trackRoute 에 따라 자동:
//       trackRoute=false (홈 화면) → bottom 220 (위치 핀을 화면 상단으로 올려 하단 버튼에 안 가리게)
//       trackRoute=true (러닝 화면) → zero
//   - 명시값을 받으면 그대로 사용 — 일시정지 모드 A 처럼 외부에서 동적 패딩을 줘야 할 때
//
// 메인 RunningScreen 의 지도는 "시작 화면 = 현재 위치만 표시" 역할이라 trackRoute false.
// 일시정지 화면의 지도는 누적 경로 표시 역할이라 trackRoute true.
class RunningMapView extends ConsumerStatefulWidget {
  final bool trackRoute;
  final EdgeInsets? contentPadding;

  const RunningMapView({
    super.key,
    this.trackRoute = false,
    this.contentPadding,
  });

  @override
  ConsumerState<RunningMapView> createState() => _RunningMapViewState();
}

class _RunningMapViewState extends ConsumerState<RunningMapView> {
  late final RunningNotifier _notifier;

  // 재시도 시 증가 → MapView 를 key 로 강제 재생성해 onMapReady 재실행
  int _mapRetryKey = 0;

  OverlayEntry? _locationErrorOverlay;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(runningViewModelProvider.notifier);
  }

  @override
  void dispose() {
    _removeOverlay();
    _notifier.clearMapController();
    super.dispose();
  }

  void _showLocationErrorOverlay() {
    _removeOverlay();
    _locationErrorOverlay = OverlayEntry(builder: (_) => _LocationErrorBanner(
      onRetry: () {
        _removeOverlay();
        setState(() => _mapRetryKey++);
      },
    ));
    Overlay.of(context).insert(_locationErrorOverlay!);
  }

  void _removeOverlay() {
    _locationErrorOverlay?.remove();
    _locationErrorOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return MapView(
      key: ValueKey(_mapRetryKey),
      showCurrentLocation: true,
      // 홈 화면(trackRoute=false)에서는 지도 스크롤 비활성화
      scrollGesturesEnable: widget.trackRoute,
      // contentPadding 결정:
      //   1) 외부에서 명시적으로 받았으면(예: 일시정지 active 화면이 동적 패딩 전달) 그대로 사용
      //   2) 안 받았으면 trackRoute 에 따라 자동 — 홈 화면은 핀이 하단 버튼에 가리지 않게 위로 올림
      contentPadding: widget.contentPadding ??
          (widget.trackRoute
              ? EdgeInsets.zero
              : const EdgeInsets.only(bottom: 220)),
      onMapReady: (mapController) {
        if (widget.trackRoute) {
          ref
              .read(runningViewModelProvider.notifier)
              .setMapController(mapController);
        }
      },
      onLocationError: () {
        if (mounted) _showLocationErrorOverlay();
      },
    );
  }
}

class _LocationErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _LocationErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.location_off_outlined,
                  color: Color(0xFFFFD60A), size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '위치를 가져올 수 없습니다. 위치 권한을 확인해 주세요.',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF60A5FA).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '재시도',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

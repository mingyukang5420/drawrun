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
// 메인 RunningScreen 의 지도는 "시작 화면 = 현재 위치만 표시" 역할이라 false.
// 일시정지 시트의 지도는 누적 경로 표시 역할이라 true.
class RunningMapView extends ConsumerStatefulWidget {
  final bool trackRoute;

  const RunningMapView({super.key, this.trackRoute = false});

  @override
  ConsumerState<RunningMapView> createState() => _RunningMapViewState();
}

class _RunningMapViewState extends ConsumerState<RunningMapView> {
  late final RunningNotifier _notifier;

  // 위치를 가져오지 못했을 때 true → 안내 오버레이 표시
  bool _locationError = false;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(runningViewModelProvider.notifier);
  }

  @override
  void dispose() {
    _notifier.clearMapController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapView(
          showCurrentLocation: true,
          onMapReady: (mapController) {
            if (widget.trackRoute) {
              ref
                  .read(runningViewModelProvider.notifier)
                  .setMapController(mapController);
            }
          },
          // 위치 실패 → 에러 상태 갱신
          onLocationError: () {
            if (mounted) setState(() => _locationError = true);
          },
        ),
        // 위치 실패 시 재시도 안내 오버레이
        if (_locationError)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off_outlined,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '위치를 가져올 수 없습니다.\n위치 권한을 확인해 주세요.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                    // 재시도 버튼: 에러 플래그 초기화 → MapView 가 다시 위치 요청
                    GestureDetector(
                      onTap: () => setState(() => _locationError = false),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
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
          ),
      ],
    );
  }
}

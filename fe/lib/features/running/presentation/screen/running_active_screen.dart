import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/widgets/running_map_view.dart';
import 'package:running/features/running/presentation/widgets/running_metric_top_bar.dart';
import 'package:running/features/running/presentation/widgets/running_stop_long_press_button.dart';
import 'package:running/features/running/presentation/widgets/running_pause_metric_column.dart';
import 'package:running/features/running/presentation/screen/running_result_screen.dart';

// 러닝 진행 화면.
// 공유 RunningMapView 를 Stack 0번 자식 자리에 단 한 번만 마운트하고,
// 그 위에 isPaused 값에 따라 두 종류의 오버레이를 얹는다.
//   - false: _RunningOverlay (상단 메트릭 바 + 우측 하단 내 위치 + 하단 일시정지 버튼)
//   - true : _PausedOverlay  (메트릭 컬럼 + 정지/재생 버튼 + 모드 B 시 우측 하단 [내위치]/[X])
// 핵심: isPaused 토글이나 일시정지 모드 A/B 토글에도 RunningMapView 의 widget identity 가
//      절대 흔들리지 않아 NaverMap PlatformView 가 재생성되지 않는다 (저사양 기기 끊김 회피).
class RunningActiveScreen extends ConsumerStatefulWidget {
  const RunningActiveScreen({super.key});

  @override
  ConsumerState<RunningActiveScreen> createState() =>
      _RunningActiveScreenState();
}

class _RunningActiveScreenState extends ConsumerState<RunningActiveScreen>
    with WidgetsBindingObserver {
  // 일시정지 화면의 오버레이(메트릭+버튼) 표시 여부
  // 공유 지도와 형제 위치에 있어야 토글 시 지도의 contentPadding / IgnorePointer 도
  // 함께 갱신 가능하므로, 이전엔 _PausedBodyState 가 보유하던 상태를 부모로 끌어올림.
  // 진행 중 모드(isPaused=false) 에서는 사용되지 않지만 상태는 그대로 살아 있어
  // 다음 일시정지 진입 시 직전 값(보통 true) 이 그대로 적용된다.
  bool _showPauseOverlay = true;

  @override
  void initState() {
    super.initState();
    // 라이프사이클 콜백 수신 등록. 등록 안 하면 didChangeAppLifecycleState 가 안 불린다.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 위젯 사라질 때 반드시 해제 — 등록 누적되면 dead-State 호출로 오류.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // resumed = 다시 포그라운드로 복귀.
    // inactive / paused / hidden 등 다른 상태는 무시 — 백그라운드 동안엔 어차피 화면을 못 본다.
    if (state == AppLifecycleState.resumed) {
      // Notifier 의 동기화 메서드를 호출해 표시 시간을 즉시 맞춘다.
      ref.read(runningViewModelProvider.notifier).syncFromBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    // isPaused 변화에 부수 효과로 카메라 재중앙
    // 러닝 중 → 일시정지 / 일시정지 → 러닝 중 두 방향 모두 호출
    // 일시정지 모드 A ↔ B (탭 / X) 같은 내부 토글에는 트리거되지 않음 — _showPauseOverlay 는 watch 대상이 아님
    // 새 contentPadding 이 native 측에 적용되는 같은 프레임 안에서 카메라 이동을 호출하면
    // 옛 기준으로 잡힐 수 있으므로 한 프레임 미뤄 보장 — method channel FIFO 순서로
    // contentPadding 갱신이 먼저, 카메라 이동이 그 뒤에 처리됨
    ref.listen<bool>(
      runningViewModelProvider.select((s) => s.isPaused),
      (previous, next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(runningViewModelProvider.notifier).centerOnCurrentLocation();
        });
      },
    );

    final isPaused =
    ref.watch(runningViewModelProvider.select((s) => s.isPaused));
    final notifier = ref.read(runningViewModelProvider.notifier);
    final size = MediaQuery.of(context).size;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    // 일시정지 모드 A 의 오버레이 패널 높이 — 화면의 57% (지도가 위쪽 ~43% 노출)
    final overlayHeight = size.height * 0.57;

    // 일시정지 + 모드 A 일 때만 지도 잠금 / 위쪽 노출용 contentPadding 적용
    // 그 외(진행 중, 일시정지 모드 B) 에는 지도 자유, contentPadding 0
    final mapLocked = isPaused && _showPauseOverlay;
    final mapPadding = mapLocked
        ? EdgeInsets.only(bottom: overlayHeight)
        : EdgeInsets.zero;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // 0번 자식 — 공유 NaverMap. 이 자리는 절대 흔들리지 않는다.
              // isPaused 토글, _showPauseOverlay 토글 모두 widget identity 를 유지하므로
              // NaverMap PlatformView 가 재생성되지 않는다.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: mapLocked,
                  child: RunningMapView(
                    trackRoute: true,
                    contentPadding: mapPadding,
                  ),
                ),
              ),

              // 1번 자식 — 모드별 오버레이 (자체 지도 없음, 부모 Stack 의 지도 위에 얹힘)
              if (isPaused)
                _PausedOverlay(
                  showOverlay: _showPauseOverlay,
                  overlayHeight: overlayHeight,
                  bottomSafe: bottomSafe,
                  onTapMap: () => setState(() => _showPauseOverlay = false),
                  onClose: () {
                    setState(() => _showPauseOverlay = true);
                    // 모드 B 에서 자유 패닝한 뒤 X 를 누르면 카메라가 패닝된 위치에 멈춰 있어
                    // 모드 A 위쪽 노출 영역에 내 위치 핀이 안 보일 수 있다 — 자동 재중앙으로 보정
                    notifier.centerOnCurrentLocation();
                  },
                  onStop: () async {
                    await notifier.finish();
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RunningResultScreen(),
                      ),
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  onResume: notifier.resume,
                  onRecenter: notifier.centerOnCurrentLocation,
                )
              else
                _RunningOverlay(
                  onPause: notifier.pause,
                  onRecenter: notifier.centerOnCurrentLocation,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 진행 중 모드 오버레이.
// 자체 지도를 가지지 않음 — 부모 Stack 의 공유 RunningMapView 위에 얹힌다.
// ─────────────────────────────────────────────────────────────────────
class _RunningOverlay extends StatelessWidget {
  final VoidCallback onPause;
  final VoidCallback onRecenter;

  const _RunningOverlay({
    required this.onPause,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 상단 메트릭 바 — 지도 위에 떠 있으므로 흰 배경으로 지도를 가린다.
        // RunningMetricTopBar 위젯 자체는 손대지 않고 호출부에서 Container 로 감싼다
        // (다른 사용처에 영향이 가지 않게).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.white,
            child: const RunningMetricTopBar(),
          ),
        ),

        // 우측 하단 "내 위치로" 버튼
        // bottom: 88 = 16(padding) + 56(버튼) + 16(간격) — 일시정지 버튼 위로 정확히 16px 떨어진 자리
        Positioned(
          right: 16,
          bottom: 88,
          child: _RecenterButton(onTap: onRecenter),
        ),

        // 하단 일시정지 버튼 (가로 풀폭)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              // ElevatedButton 자체에 그림자가 있어 별도 Material 래핑 없이도 떠 있는 느낌
              height: 56,
              child: ElevatedButton(
                onPressed: onPause,
                child: const Icon(Icons.pause, size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 지도 우측 하단에 띄우는 작은 원형 플로팅 버튼
// 탭하면 부모가 주입한 onTap(=내 위치로 카메라 이동) 이 실행된다
class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Material + InkWell 조합 — 탭 리플(파동) 효과와 그림자를 함께 얻기 위한 정석 패턴
    return Material(
      color: Colors.white,
      // 약간의 그림자로 지도 위에서 떠 있는 느낌을 준다
      elevation: 4,
      shape: const CircleBorder(),
      // 자식의 클릭 영역도 원형으로 잘라낸다 (모서리 바깥 탭이 안 먹게)
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          // my_location 아이콘은 네이버 지도 / 구글 지도의 위치 버튼과 동일한 관용 표현
          child: Icon(
            Icons.my_location,
            size: 22,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 일시정지 모드 오버레이.
// 자체 상태도, 자체 지도도 갖지 않는다 — StatelessWidget 으로 단순화.
// _showOverlay 는 부모(_RunningActiveScreenState) 가 관리하고 콜백/플래그로만 받음.
// ─────────────────────────────────────────────────────────────────────
class _PausedOverlay extends StatelessWidget {
  final bool showOverlay;
  final double overlayHeight;
  final double bottomSafe;
  final VoidCallback onTapMap;
  final VoidCallback onClose;
  final Future<void> Function() onStop;
  final VoidCallback onResume;
  final VoidCallback onRecenter;

  const _PausedOverlay({
    required this.showOverlay,
    required this.overlayHeight,
    required this.bottomSafe,
    required this.onTapMap,
    required this.onClose,
    required this.onStop,
    required this.onResume,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 모드 A — 투명 탭 감지 레이어 (지도가 보이는 위쪽 영역의 탭을 잡아 모드 B 로 전환)
        // z-순서상 아래의 오버레이 패널이 자기 영역 탭을 먼저 가로채므로
        // 결과적으로 "지도가 보이는 위쪽 영역" 의 탭만 잡힌다
        if (showOverlay)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapMap,
            ),
          ),

        // 모드 A — 메트릭 + 정지/재생 버튼 패널
        // 화면 아래 57% 를 흰 패널로 덮어 지도를 가린다
        if (showOverlay)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: overlayHeight,
              child: _OverlayPanel(
                onStop: onStop,
                onResume: onResume,
                bottomSafe: bottomSafe,
              ),
            ),
          ),

        // 모드 B — 우측 하단 [내 위치로] / [X 닫기]
        if (!showOverlay)
          Positioned(
            right: 16,
            bottom: 16 + bottomSafe,
            child: _ActionButtonsColumn(
              onRecenter: onRecenter,
              onClose: onClose,
            ),
          ),
      ],
    );
  }
}

// 일시정지 화면 모드 A 의 흰 오버레이 패널
// 메트릭 컬럼(상단) + 빈 공간(Spacer) + 정지/재생 버튼(하단)
class _OverlayPanel extends StatelessWidget {
  final Future<void> Function() onStop;
  final VoidCallback onResume;
  // 시스템 UI(홈 인디케이터) 보정값 — 부모에서 받아온다
  final double bottomSafe;

  const _OverlayPanel({
    required this.onStop,
    required this.onResume,
    required this.bottomSafe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 흰 배경으로 그 아래 지도를 가린다
      // 상단 경계선 한 줄로 지도와 시각 구분
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          // 메트릭 컬럼 — 패널 상단에 배치
          // 상하 24 / 좌우 16 패딩으로 가장자리 호흡
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: RunningPauseMetricColumn(),
          ),

          // 빈 공간 — 메트릭과 버튼 사이 호흡
          const Spacer(),

          // 정지(롱프레스) / 재생 버튼
          // 누르기 편한 위치로 — 하단 가장자리에서 48px 추가로 더 위
          // 16(기본) + bottomSafe(시스템 UI) + 48(추가 띄움) = 약 80~104px 위
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomSafe + 48),
            child: Row(
              children: [
                Expanded(
                  child: RunningStopLongPressButton(onLongPressed: onStop),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onResume,
                      child: const Icon(Icons.play_arrow, size: 32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 일시정지 화면 모드 B 의 우측 하단 액션 버튼 묶음
// [내 위치로] (위) / [X 닫기] (아래)
// 부모에서 콜백 두 개를 받기만 하면 되어 StatelessWidget 으로 충분 (ref 사용 안 함)
class _ActionButtonsColumn extends StatelessWidget {
  final VoidCallback onRecenter;
  final VoidCallback onClose;
  const _ActionButtonsColumn({
    required this.onRecenter,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      // 자식 합만큼만 높이를 차지 — Positioned 안에서 위로 늘어나지 않게
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _RoundIconButton(icon: Icons.my_location, onTap: onRecenter),
        const SizedBox(height: 12),
        _RoundIconButton(icon: Icons.close, onTap: onClose),
      ],
    );
  }
}

// 흰 배경 + 그림자가 있는 원형 아이콘 버튼
// 진행 중 화면의 _RecenterButton 과 동일 디자인 — 시각 톤 통일
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Material + InkWell — 탭 리플 효과와 그림자를 함께 얻기 위한 정석
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: Colors.black87),
        ),
      ),
    );
  }
}

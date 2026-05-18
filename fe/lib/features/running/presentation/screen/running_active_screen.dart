import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/widgets/running_map_view.dart';
import 'package:running/features/running/presentation/widgets/running_metric_top_bar.dart';
import 'package:running/features/running/presentation/widgets/running_stop_long_press_button.dart';
import 'package:running/features/running/presentation/widgets/running_pause_metric_column.dart';
import 'package:running/features/running/presentation/screen/running_result_screen.dart';

// 러닝 진행 화면. isPaused 값에 따라 두 모드를 분기 렌더링한다.
//   - false: _RunningBody (상단 메트릭 + 가운데 지도 + 하단 일시정지 버튼)
//   - true : _PausedBody  (지도 단일 마운트 + 오버레이 토글)
class RunningActiveScreen extends ConsumerStatefulWidget {
  const RunningActiveScreen({super.key});

  @override
  ConsumerState<RunningActiveScreen> createState() =>
      _RunningActiveScreenState();
}

class _RunningActiveScreenState extends ConsumerState<RunningActiveScreen>
    with WidgetsBindingObserver {
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
    // 기존 build 코드를 그대로 옮긴다 — isPaused 분기 / _RunningBody / _PausedBody.
    final isPaused =
    ref.watch(runningViewModelProvider.select((s) => s.isPaused));
    final notifier = ref.read(runningViewModelProvider.notifier);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: isPaused
              ? _PausedBody(
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
          )
              : _RunningBody(
            onPause: notifier.pause,
            onRecenter: notifier.centerOnCurrentLocation,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 러닝 중 모드: 자체 상태 없음 (포커스 인덱스는 자식 MetricFocus 가 관리).
// 분리한 이유: isPaused 가 바뀔 때 이 위젯만 새로 만들어지므로 리빌드 범위가 좁아진다.
// ─────────────────────────────────────────────────────────────────────
class _RunningBody extends StatelessWidget {
  final VoidCallback onPause;
  final VoidCallback onRecenter;

  const _RunningBody({
    required this.onPause,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 3분할 (시간 / 거리 / 페이스)
        const RunningMetricTopBar(),

        // 가운데: 실시간 지도 + 우측 하단 "내 위치로" 버튼을 Stack 으로 겹친다
        // Stack 은 자식들을 z-축 방향(뒤→앞) 으로 쌓는 레이아웃이다
        // 첫 자식(지도) 이 바닥에 깔리고, Positioned 자식이 그 위에 뜬다
        Expanded(
          child: Stack(
            children: [
              // 1번 자식 (z 최하단) — 화면 전체를 채우는 실시간 지도
              const Positioned.fill(
                child: RunningMapView(trackRoute: true),
              ),

              // 2번 자식 — 우측 하단 "내 위치로" 버튼
              // 일시정지 버튼 위로 올라가 겹치지 않게: 88 = 16(padding) + 56(버튼) + 16(간격)
              Positioned(
                right: 16,
                bottom: 88,
                child: _RecenterButton(onTap: onRecenter),
              ),

              // 3번 자식 (z 최상단) — 일시정지 버튼을 지도 위에 띄운다
              // bottom: 0 / left: 0 / right: 0 — Stack 밑변에 가로 풀폭으로 붙임
              // 내부 Padding(16) 으로 가장자리에 닿지 않게 — 일시정지 화면의 정지/재생 버튼과 동일 패턴
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

// StatelessWidget → StatefulWidget
// 오버레이 표시/숨김 상태를 위젯 내부에 들고, setState 한 번으로 토글
// 중요: 이 토글은 0번 자식인 RunningMapView 의 widget identity 를 절대 흔들지 않는다
//       → NaverMap PlatformView 가 재생성되지 않아 저사양 기기에서 끊김이 없음
class _PausedBody extends StatefulWidget {
  // Future 반환: 정지 → 화면 이동을 직렬로 보장하기 위해 VoidCallback 이 아닌 Future 사용
  final Future<void> Function() onStop;
  final VoidCallback onResume;

  const _PausedBody({
    required this.onStop,
    required this.onResume,
  });

  @override
  State<_PausedBody> createState() => _PausedBodyState();
}

class _PausedBodyState extends State<_PausedBody> {
  // 메트릭/버튼 오버레이 표시 여부
  // true  → 모드 A (오버레이 ON, 지도 위쪽 일부만 노출, 지도 제스처 잠금)
  // false → 모드 B (오버레이 OFF, 지도 전체 노출, 자유 제스처, 우측 하단 [내위치]/[X] 버튼)
  bool _showOverlay = true;

  @override
  Widget build(BuildContext context) {
    // 시스템 UI(홈 인디케이터 / 제스처 바) 영역만큼 버튼을 위로 띄울 보정값
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    // 오버레이 패널 높이 — 화면의 57% (지도가 위쪽 ~43% 노출되도록)
    final overlayHeight = MediaQuery.of(context).size.height * 0.57;

    return Stack(
      children: [
        // 1번 자식 — 항상 화면 전체 크기로 마운트되어 있는 지도
        // _showOverlay 토글에도 이 자리는 절대 흔들리지 않는다 → PlatformView 재생성 없음
        // IgnorePointer 의 ignoring 과 RunningMapView 의 contentPadding 만 변경되며,
        // RunningMapView 의 State (그리고 NaverMapController 참조) 는 동일하게 유지된다
        Positioned.fill(
          child: IgnorePointer(
            // 모드 A 에서는 지도 제스처 차단, 모드 B 에서는 자유 제스처
            ignoring: _showOverlay,
            // contentPadding 으로 지도의 "실효 가시 영역" 을 정의 — 카메라가 그 영역의
            // 중앙에 target 을 놓는다
            //   모드 A: bottom = overlayHeight → 위쪽 ~43% 영역의 중앙에 내 위치 핀이 표시됨
            //   모드 B: zero → 전체 화면 기준
            child: RunningMapView(
              trackRoute: true,
              contentPadding: _showOverlay
                  ? EdgeInsets.only(bottom: overlayHeight)
                  : EdgeInsets.zero,
            ),
          ),
        ),

        // 2번 자식 — 모드 A 일 때만 활성화되는 투명 탭 감지 레이어
        // 화면 전체를 덮지만, z-순서상 아래의 오버레이 패널(3번 자식)이 자기 영역 탭을 먼저 가로채므로
        // 결과적으로 "지도가 보이는 위쪽 영역" 의 탭만 잡힌다
        if (_showOverlay)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showOverlay = false),
            ),
          ),

        // 3번 자식 — 메트릭 + 정지/재생 버튼 오버레이 패널 (모드 A)
        // 화면 아래 57% 를 흰 패널로 덮어 지도를 가린다
        // 패널 안 메트릭은 위쪽, 버튼은 아래쪽에 배치하고 그 사이는 Spacer 로 호흡
        if (_showOverlay)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SizedBox(
              height: overlayHeight,
              child: _OverlayPanel(
                onStop: widget.onStop,
                onResume: widget.onResume,
                bottomSafe: bottomSafe,
              ),
            ),
          ),

        // 4번 자식 — 모드 B 일 때만 보이는 우측 하단 액션 버튼 묶음
        // [내 위치로] (위) / [X 닫기 = 오버레이 다시 표시] (아래)
        if (!_showOverlay)
          Positioned(
            right: 16,
            bottom: 16 + bottomSafe,
            child: _ActionButtonsColumn(
              onClose: () => setState(() => _showOverlay = true),
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
// ConsumerWidget — viewmodel 의 centerOnCurrentLocation 호출용으로 ref 필요
class _ActionButtonsColumn extends ConsumerWidget {
  // X 닫기 콜백 — 부모(_PausedBodyState) 에서 setState 로 오버레이를 다시 켠다
  final VoidCallback onClose;
  const _ActionButtonsColumn({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(runningViewModelProvider.notifier);

    return Column(
      // 자식 합만큼만 높이를 차지하도록 — Positioned 안에서 위로 늘어나지 않게
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 내 위치로 — viewmodel 의 centerOnCurrentLocation 재사용
        _RoundIconButton(
          icon: Icons.my_location,
          onTap: notifier.centerOnCurrentLocation,
        ),
        // 두 버튼 사이 간격
        const SizedBox(height: 12),
        // X 닫기 — 모드 A 로 되돌리는 토글 + 내 위치 자동 재중앙
        // 모드 B 에서 자유 패닝한 뒤 X 를 누르면 카메라가 패닝된 위치에 멈춰 있어
        // 모드 A 위쪽 노출 영역에 내 위치 핀이 안 보일 수 있다 — 이걸 막기 위해
        // 오버레이 토글과 동시에 내 위치로 카메라를 가져온다
        _RoundIconButton(
          icon: Icons.close,
          onTap: () {
            notifier.centerOnCurrentLocation();
            onClose();
          },
        ),
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
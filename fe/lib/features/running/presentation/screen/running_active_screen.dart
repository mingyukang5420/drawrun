import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/widgets/running_map_view.dart';
import 'package:running/features/running/presentation/widgets/running_metric_top_bar.dart';
import 'package:running/features/running/presentation/widgets/running_pause_metric_grid.dart';
import 'package:running/features/running/presentation/widgets/running_stop_long_press_button.dart';
import 'package:running/features/running/presentation/screen/running_result_screen.dart';

// 러닝 진행 화면. isPaused 값에 따라 두 모드를 분기 렌더링한다.
//   - false: _RunningBody (상단 메트릭 + 가운데 큰 값 + 하단 일시정지 버튼)
//   - true : _PausedBody  (그리드 + 정지(롱프레스)/재생 + 위로 끄는 지도 시트)
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
            // VM 의 카메라 이동 메서드를 그대로 넘긴다
            // 메서드 참조(notifier.centerOnCurrentLocation) 로 넘기면 매 빌드마다
            // 새 람다가 생성되지 않아 자식 위젯 입장에서 const 처럼 안정적이다
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
              // 바닥 레이어 — Positioned.fill 로 부모 영역을 가득 채우게 한다
              const Positioned.fill(
                child: RunningMapView(trackRoute: true),
              ),

              // 우측 하단에 띄우는 "내 위치로" 플로팅 버튼
              // 16px 여백은 일반적인 FAB 여백 — 상단 메트릭 바와 시각적 균형
              Positioned(
                right: 16,
                bottom: 16,
                child: _RecenterButton(onTap: onRecenter),
              ),
            ],
          ),
        ),

        // 하단: 일시정지 버튼 (그대로)
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onPause,
              child: const Icon(Icons.pause, size: 32),
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
// 일시정지 모드: 그리드 + 정지/재생 버튼 + (z-축 위로) DraggableScrollableSheet.
// Stack 으로 시트를 위에 띄워야 그리드/버튼을 가리지 않으면서 끌어올릴 수 있다.
// ─────────────────────────────────────────────────────────────────────
class _PausedBody extends StatelessWidget {
  // Future 반환: 정지 → 화면 이동을 직렬로 보장하기 위해 VoidCallback 이 아닌 Future 사용
  final Future<void> Function() onStop;
  final VoidCallback onResume;
  const _PausedBody({required this.onStop, required this.onResume});

  @override
  Widget build(BuildContext context) {
    // z-순서 뒤집기: 지도를 화면 전체 배경으로 깔고, 그리드와 버튼을 그 위에 띄운다
    // Stack 자식 리스트는 [앞쪽=뒤(아래), 뒤쪽=앞(위)] 순으로 그려진다
    return Stack(
      children: [
        // 1번 자식 (z 최하단) — 화면 전체를 채우는 실시간 지도
        // Positioned.fill 은 Stack 부모 영역 전부를 자식이 차지하게 만드는 단축형
        // trackRoute: true — 진행 중에 그리던 파란 폴리라인을 그대로 이어서 보여 준다
        const Positioned.fill(
          child: RunningMapView(trackRoute: true),
        ),

        // 2번 자식 — 6분할 메트릭 그리드를 화면 상단에 가로 풀폭으로 띄운다
        // top: 0, left: 0, right: 0 — 양옆·위 가장자리까지 가득 채워 그 아래 지도를 가린다
        // 진행 중 화면의 RunningMetricTopBar 와 동일한 시각 톤 (둥근 모서리 / 그림자 없음)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            // 흰 배경으로 지도를 가려 그리드 텍스트가 또렷이 읽히게 한다
            // 하단 경계선 한 줄(black12) 로 지도와 시각 구분 — 진행 중 상단 바와 동일 패턴
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            // 내부 여백 — 그리드 셀이 바 가장자리에 너무 붙지 않게
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: const RunningPauseMetricGrid(),
          ),
        ),

        // 3번 자식 (z 최상단) — 정지(롱프레스) / 재생 버튼을 화면 하단에 띄운다
        // bottom: 0 / left: 0 / right: 0 — Stack 밑변에 가로 폭 가득
        // ElevatedButton 은 자체 elevation 을 갖고 있어 별도 Material 래핑 불필요
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            // 화면 하단에서 16px 여백 — 진행 중 화면의 일시정지 버튼과 동일
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Expanded 로 두 버튼을 화면 폭에 맞춰 균등 분할
                Expanded(
                  child: RunningStopLongPressButton(onLongPressed: onStop),
                ),
                // 두 버튼 사이 12px 간격
                const SizedBox(width: 12),
                Expanded(
                  // 정지 버튼 높이와 맞추기 위해 SizedBox 로 56px 고정
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
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/widgets/running_map_view.dart';
import 'package:running/features/running/presentation/widgets/running_metric_top_bar.dart';
import 'package:running/features/running/presentation/widgets/running_pause_map_sheet.dart';
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
              : _RunningBody(onPause: notifier.pause),
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
  const _RunningBody({required this.onPause});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 3분할 (시간 / 거리 / 페이스)
        const RunningMetricTopBar(),
        // 가운데: 실시간 지도
        // trackRoute: true 로 넘기면 RunningMapView 가 NaverMapController 를
        // RunningNotifier 에 등록하고, VM 이 누적된 경로(파란 폴리라인) 와
        // 참조 노드(회색 폴리라인) 를 자동으로 그려준다
        // Expanded 로 상단 바와 하단 버튼 사이 가용 높이를 모두 차지하게 한다
        const Expanded(child: RunningMapView(trackRoute: true)),
        // 하단: 일시정지 버튼 (가로 꽉 채우기)
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity, // 부모 가용 폭 모두 사용
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
    return Stack(
      children: [
        // 1번 레이어: 그리드 + 버튼 (시트보다 아래)
        Column(
          children: [
            // 6분할 메트릭 그리드 (거리 / 평균페이스 / 시간 / 칼로리 / 고도 / BPM)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: RunningPauseMetricGrid(),
            ),
            // 그리드와 버튼 사이 빈 공간 차지
            const Spacer(),
            // 정지(3초 롱프레스) / 재생 버튼을 좌우로 균등 배치
            Padding(
              padding: const EdgeInsets.all(16),
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
            // 시트의 핸들이 화면 맨 아래에서 빼꼼 보이도록 그만큼의 여백 확보
            const SizedBox(height: 80),
          ],
        ),
        // 2번 레이어: 위로 드래그하면 커지는 지도 시트
        const RunningPauseMapSheet(),
      ],
    );
  }
}
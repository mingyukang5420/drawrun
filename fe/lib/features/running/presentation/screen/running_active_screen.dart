import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/widgets/running_metric_focus.dart';
import 'package:running/features/running/presentation/widgets/running_metric_top_bar.dart';
import 'package:running/features/running/presentation/widgets/running_pause_map_sheet.dart';
import 'package:running/features/running/presentation/widgets/running_pause_metric_grid.dart';
import 'package:running/features/running/presentation/widgets/running_stop_long_press_button.dart';
import 'package:running/features/running/presentation/screen/running_result_screen.dart';

// 러닝 진행 화면. isPaused 값에 따라 두 모드를 분기 렌더링한다.
//   - false: _RunningBody (상단 메트릭 + 가운데 큰 값 + 하단 일시정지 버튼)
//   - true : _PausedBody  (그리드 + 정지(롱프레스)/재생 + 위로 끄는 지도 시트)
class RunningActiveScreen extends ConsumerWidget {
  const RunningActiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .select((s) => s.isPaused): isPaused 값이 변할 때만 이 build 가 다시 실행된다.
    // state 통째로 watch 하면 elapsedSeconds 1초 갱신마다 분기 위젯이 통째로 다시 만들어져 비효율.
    final isPaused =
    ref.watch(runningViewModelProvider.select((s) => s.isPaused));
    // pause/resume/finish 메서드 호출 전용 → read
    final notifier = ref.read(runningViewModelProvider.notifier);

    // 시스템 뒤로가기 차단: 러닝 데이터 손실 방지
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: isPaused
              ? _PausedBody(
            // 정지 시: finish() 후 탭으로 복귀
            onStop: () async {
              // 1) 측정 정리 — GPS 구독 해제, 타이머 종료, endedAt 기록
              await notifier.finish();
              if (!context.mounted) return;

              // 2) 결과 화면을 push.
              //    pushReplacement 가 아니라 push 인 이유:
              //    runningViewModelProvider 는 autoDispose. RunningActiveScreen 을 닫으면
              //    Provider 도 같이 정리되어 state(distanceKm, points 등) 가 날아감.
              //    push 로 쌓으면 ActiveScreen 이 뒤에 살아있어 Provider 가 유지됨.
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RunningResultScreen(),
                ),
              );
              // 3) 결과 화면이 pop 으로 닫히고 돌아온 시점.
              //    ActiveScreen 까지 함께 닫고 루트(탭)로 복귀.
              if (!context.mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            // 재생 시: GPS 재구독 + 타이머 재시작
            onResume: notifier.resume,
          )
          // 러닝 중 → 일시정지 트리거
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
        // 가운데: 큰 값 표시. Expanded 로 가용 높이를 모두 차지
        const Expanded(child: RunningMetricFocus()),
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
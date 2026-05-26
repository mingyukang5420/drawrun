import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';

// 일시정지 화면 중단부 — 6개 지표(시간·거리·페이스 | 칼로리·고도·케이던스)를
// 박스 없이 가는 세로선 한 줄로만 나눠서 2행 3열로 표시
// 진행 중 화면의 RunningMetricTopBar 와 같은 시각 톤
class RunningPauseMetricColumn extends ConsumerWidget {
  const RunningPauseMetricColumn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // state 가 바뀔 때마다 위젯 리빌드 — 케이던스 같은 1초 단위 갱신 항목 반영
    final state = ref.watch(runningViewModelProvider);

    // mainAxisSize: min — Column 이 자식 합만큼만 높이를 차지
    // 두 행 사이는 SizedBox 16 으로 좁게 — 이전 spaceEvenly 보다 한층 가까운 시각 톤
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 상단 행 — 시간 | 거리 | 페이스
        Row(
          children: [
            _Cell(label: '시간', value: state.elapsedLabel),
            const _Divider(),
            _Cell(label: '거리', value: state.distanceLabel),
            const _Divider(),
            _Cell(label: '페이스', value: state.paceLabel),
          ],
        ),
        // 두 행 사이 간격 — 너무 멀지 않게
        const SizedBox(height: 16),
        // 하단 행 — 칼로리 | 고도 | 케이던스
        Row(
          children: [
            _Cell(label: '칼로리', value: state.caloriesLabel),
            const _Divider(),
            _Cell(label: '고도', value: state.altitudeLabel),
            const _Divider(),
            _Cell(label: '케이던스', value: state.cadenceLabel),
          ],
        ),
      ],
    );
  }
}

// 한 칸의 메트릭(라벨 + 값) 표시
// Expanded 로 Row 안에서 가용 폭을 균등 분할
class _Cell extends StatelessWidget {
  final String label;
  final String value;
  const _Cell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 작고 흐린 라벨 — 진행 중 상단 바와 동일 스타일
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          // 굵은 큰 값 — 일시정지에서는 차분히 보는 화면이라 진행 중 상단 바(18) 보다 살짝 크게(20)
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// 셀과 셀 사이의 얇은 세로 구분선
class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: Colors.black12);
}
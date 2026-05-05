import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';

// 러닝 일시정지 시 지표 격자 표시 위젯 (거리·시간·칼로리 등)
// TODO: 미구현
class RunningPauseMetricGrid extends ConsumerWidget {
  const RunningPauseMetricGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runningViewModelProvider);

    // (라벨, 값) 레코드 6개. 디자인 시안 순서대로 배치
    final cells = [
      ('거리', state.distanceLabel),
      ('평균 페이스', state.avgPaceLabel),
      ('시간', state.elapsedLabel),
      ('칼로리', state.caloriesLabel),
      ('고도', state.altitudeLabel),
      ('BPM', state.bpmLabel),
    ];

    return GridView.count(
      // 한 줄에 셀 3개
      crossAxisCount: 3,
      // 셀 가로:세로 비율
      childAspectRatio: 1.4,
      // 부모(Column) 안에 들어가므로 자체 콘텐츠 만큼만 높이 사용
      shrinkWrap: true,
      // 부모가 스크롤을 결정하므로 자체 스크롤은 끔
      physics: const NeverScrollableScrollPhysics(),
      // 레코드의 위치 기반 접근자: 첫 번째 = .$1, 두 번째 = .$2
      children: cells
          .map((c) => _GridCell(label: c.$1, value: c.$2))
          .toList(),
    );
  }
}

// 한 칸의 메트릭 박스 (테두리 + 라벨 + 값)
class _GridCell extends StatelessWidget {
  final String label;
  final String value;
  const _GridCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      // 테두리 + 둥근 모서리로 카드처럼 보이게
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      child: Column(
        // 셀 안에서 세로 가운데 정렬
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 작고 흐린 라벨
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 4),
          // 굵은 값
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';

// 러닝 중 화면 상단의 가로 3분할 지표 바: 시간 | 거리 | 페이스.
// 세 값 모두 1초 단위로 갱신되므로 select 없이 state 통째 watch 하는 게 효율 동일
class RunningMetricTopBar extends ConsumerWidget {
  const RunningMetricTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // state 가 바뀔 때마다 이 위젯이 리빌드 → 시간/거리/페이스 갱신
    final state = ref.watch(runningViewModelProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      // 하단 경계선으로 가운데 큰 값 영역과 시각 구분
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          // 각 셀은 Expanded 로 가용 폭을 균등 분할
          _Cell(label: '시간', value: state.elapsedLabel),
          const _Divider(),
          _Cell(label: '거리', value: state.distanceLabel),
          const _Divider(),
          _Cell(label: '페이스', value: state.paceLabel),
        ],
      ),
    );
  }
}

// 한 칸의 메트릭(라벨+값) 표시.
// 함수 위젯이 아닌 클래스로 만든 이유: DevTools 의 위젯 인스펙터에 클래스명이 표시돼 디버깅 용이.
class _Cell extends StatelessWidget {
  final String label;
  final String value;
  const _Cell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // Expanded: Row 안에서 자식이 가용 폭을 균등 분할하게 만든다 (없으면 텍스트 길이만큼만 차지)
    return Expanded(
      child: Column(
        children: [
          // 작고 흐린 라벨
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          // 굵은 큰 값
          Text(value,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
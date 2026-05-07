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
      // 셀 가로:세로 비율을 1.4 → 1.25 로 낮춰 셀 자체를 살짝 더 높게 잡는다.
      // 작은 폭 기기(예: 360dp) 에서 콘텐츠가 빠듯하지 않도록 세로 여유 확보.
      childAspectRatio: 1.25,
      // 셀과 셀 사이 세로 간격을 명시. 기본값 0 이면 셀이 다닥다닥 붙어
      // 안쪽 콘텐츠 높이를 한층 더 빠듯하게 만든다.
      mainAxisSpacing: 8,
      // 가로 간격도 같이 줘서 좌우 _GridCell 의 margin(EdgeInsets.all(4)) 와
      // 어우러지게 한다.
      crossAxisSpacing: 4,
      // 부모(Column) 안에 들어가므로 자체 콘텐츠 만큼만 높이 사용
      shrinkWrap: true,
      // 부모가 스크롤을 결정하므로 자체 스크롤은 끔
      physics: const NeverScrollableScrollPhysics(),
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
      // 셀의 외관 — 테두리 + 둥근 모서리.
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      // 그리드의 mainAxisSpacing/crossAxisSpacing 에서 이미 간격을 주므로
      // margin 은 0 으로 줄여 셀 안의 가용 높이를 최대한 회수한다.
      margin: EdgeInsets.zero,
      // 상하 패딩을 8 → 6 으로 살짝 줄여 빠듯한 4–6 px 오버플로 케이스를 흡수.
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        // 자식 합만큼만 높이 사용 — 셀 높이가 작아도 강제로 늘리지 않게.
        mainAxisSize: MainAxisSize.min,
        // 셀 안에서 세로 가운데 정렬
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 라벨 — 폰트 줄 높이를 1.0 으로 명시해 시스템 텍스트 스케일과
          // 무관하게 세로 합이 일정하게 잡히도록 한다.
          // FittedBox 로 폭이 좁을 때 한 번 더 자동 축소.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                height: 1.0, // 줄 간 여유 제거 — 세로 오버플로 직접 가드
              ),
            ),
          ),
          // 라벨과 값 사이 간격 — 4 → 2 로 축소.
          // 작은 차이 같지만 세로 여유 4 px 가 오버플로 직격탄이라 효과가 크다.
          const SizedBox(height: 2),
          // 값 — 라벨과 같은 height 1.0 정책 적용.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';

// 가운데 큰 값. 탭하면 시간 → 거리 → 페이스 → 심박수 순환.
// "어떤 지표를 보고 있는지"(focusIndex) 는 이 위젯만의 표시 상태이므로
// Notifier 가 아닌 위젯 자체 State 에 둔다 → ConsumerStatefulWidget.
// (Riverpod 도 써야 하므로 Stateful + Consumer 합쳐진 변형을 사용)
class RunningMetricFocus extends ConsumerStatefulWidget {
  const RunningMetricFocus({super.key});

  @override
  ConsumerState<RunningMetricFocus> createState() => _RunningMetricFocusState();
}

class _RunningMetricFocusState extends ConsumerState<RunningMetricFocus> {
  // 0:시간 1:거리 2:페이스 3:심박수
  // 초기값 3 (심박수).
  int _focusIndex = 3;

  @override
  Widget build(BuildContext context) {
    // 시간/거리/페이스/심박수 중 어느 게 선택돼도 state 가 필요 → 통째 watch
    final state = ref.watch(runningViewModelProvider);

    // (라벨, 값, 단위) 레코드 4개. Dart 3 의 레코드 + 패턴 매칭 활용.
    final items = [
      ('시간', state.elapsedLabel, ''),
      ('거리', state.distanceKm.toStringAsFixed(2), 'km'),
      ('페이스', state.paceLabel, ''),
      ('심박수', state.bpm.toString(), 'bpm'),
    ];
    // 레코드 분해: 한 줄로 세 변수에 동시에 할당
    final (label, value, unit) = items[_focusIndex];

    return GestureDetector(
      // 탭하면 다음 인덱스로 순환 (3 → 0 으로 wrap)
      onTap: () =>
          setState(() => _focusIndex = (_focusIndex + 1) % items.length),
      // 큰 텍스트 사이 빈 공간까지 탭 영역으로 인식되게 하는 트릭.
      // 기본값(deferToChild) 이면 글자 픽셀 위에서만 탭이 먹는다.
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          // 자식 합 만큼만 세로 차지 (Center 와 함께 가운데 정렬 효과)
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 64, fontWeight: FontWeight.bold)),
            // 단위가 있는 항목(거리·심박수)만 단위 텍스트 표시
            if (unit.isNotEmpty)
              Text(unit, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
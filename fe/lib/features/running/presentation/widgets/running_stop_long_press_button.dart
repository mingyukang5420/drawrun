import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 길게 누르면 러닝을 종료하는 버튼 위젯 (오작동 방지용)
// TODO: 미구현
class RunningStopLongPressButton extends ConsumerWidget {
  const RunningStopLongPressButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

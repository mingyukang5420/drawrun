import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 러닝 진행 중 화면 (지도 + 실시간 지표)
// TODO: 미구현
class RunningActiveScreen extends ConsumerWidget {
  const RunningActiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('러닝 진행 중')),
    );
  }
}

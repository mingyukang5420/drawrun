import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 러닝 시작 전 카운트다운 화면
// TODO: 미구현
class RunningCountdownScreen extends ConsumerWidget {
  const RunningCountdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('카운트다운')),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 러닝 완료 결과 화면 (거리·시간·페이스 요약)
// TODO: 미구현
class RunningResultScreen extends ConsumerWidget {
  const RunningResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('러닝 결과')),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:running/features/record/presentation/screen/record_history_screen.dart';

// 진입 화면. 06번 커밋에서 통계/히스토리 탭 구조로 다시 짠다.
// 그 전까지는 히스토리만 보여준다.
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      body: const SafeArea(child: RecordHistoryScreen()),
    );
  }
}
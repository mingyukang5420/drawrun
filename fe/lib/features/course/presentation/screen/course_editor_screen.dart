import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/widgets/course_map_view.dart';

// 코스 생성 화면
// 지도를 탭해 경로 점을 찍고, 저장 버튼으로 서버에 코스를 저장
class CourseEditorScreen extends ConsumerWidget {
  const CourseEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch: points 변경 시 저장 버튼 활성화 여부를 다시 계산한다
    final state = ref.watch(courseEditorViewModelProvider);
    final notifier = ref.read(courseEditorViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('코스 생성')),

      body: const CourseMapView(),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 점이 하나 이상 있을 때만 저장 버튼 활성화
          FloatingActionButton(
            heroTag: 'save',
            onPressed: state.points.isEmpty
                ? null
                : () => _showSaveDialog(context, ref),
            child: const Icon(Icons.save),
          ),
          const SizedBox(height: 8),
          // 경로 초기화 버튼
          FloatingActionButton(
            heroTag: 'clear',
            onPressed: notifier.clear,
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  // 코스 이름 입력 다이얼로그 표시 후 저장 처리
  void _showSaveDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('코스 이름'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: '코스 이름을 입력하세요'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext); // 다이얼로그 닫기
              // ref.read: 비동기 콜백 내부의 1회성 호출
              await ref
                  .read(courseEditorViewModelProvider.notifier)
                  .saveCourse(name);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

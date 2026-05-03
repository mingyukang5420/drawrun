import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:running/features/course/data/course_remote_datasource.dart';
import 'package:running/features/course/data/course_repository_impl.dart';
import 'package:running/features/course/presentation/course_viewmodel.dart';
import 'package:running/features/course/presentation/widgets/course_map_view.dart';
import 'package:running/shared/network/dio_client.dart';

// 코스 생성 화면
// 지도를 탭해 경로 점을 찍고, 저장 버튼으로 서버에 코스를 저장
class CourseEditorScreen extends StatelessWidget {
  const CourseEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // 의존성 체인: DioClient → Datasource → RepositoryImpl → ViewModel
      create: (_) {
        final datasource = CourseRemoteDataSource(DioClient.create());
        return CourseViewModel(CourseRepositoryImpl(datasource));
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('코스 생성')),

        body: const CourseMapView(),

        floatingActionButton: Consumer<CourseViewModel>(
          builder: (context, vm, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 점이 하나 이상 있을 때만 저장 버튼 활성화
                FloatingActionButton(
                  heroTag: 'save',
                  onPressed:
                      vm.points.isEmpty ? null : () => _showSaveDialog(context, vm),
                  child: const Icon(Icons.save),
                ),
                const SizedBox(height: 8),
                // 경로 초기화 버튼
                FloatingActionButton(
                  heroTag: 'clear',
                  onPressed: vm.clear,
                  child: const Icon(Icons.refresh),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 코스 이름 입력 다이얼로그 표시 후 저장 처리
  void _showSaveDialog(BuildContext context, CourseViewModel vm) {
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
              await vm.saveCourse(name);
              // 저장 성공 후 편집 화면 닫기
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

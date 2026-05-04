import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/course_viewmodel.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';

// 코스 목록 화면
// 서버에서 코스를 불러와 목록으로 표시하고, 삭제 및 편집 화면 이동을 제공
class CourseScreen extends ConsumerWidget {
  const CourseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch: CourseState 가 변경될 때마다 build 를 다시 실행한다
    final state = ref.watch(courseViewModelProvider);
    final notifier = ref.read(courseViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('코스')),

      body: _buildBody(state, notifier),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CourseEditorScreen()),
          ).then((_) {
            // 편집 화면에서 돌아왔을 때 목록 새로고침
            // ref.read: then 콜백은 build 바깥이므로 구독 불필요
            ref.read(courseViewModelProvider.notifier).loadCourses();
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // 상태에 따른 본문 위젯 분기
  Widget _buildBody(CourseState state, CourseNotifier notifier) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(child: Text(state.errorMessage!));
    }
    if (state.courses.isEmpty) {
      return const Center(child: Text('저장된 코스가 없습니다'));
    }
    return ListView.builder(
      itemCount: state.courses.length,
      itemBuilder: (context, index) {
        final course = state.courses[index];
        return ListTile(
          title: Text(course.name),
          subtitle: Text('${course.distanceKm.toStringAsFixed(2)} km'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: course.id != null
                ? () => notifier.deleteCourse(course.id!)
                : null,
          ),
        );
      },
    );
  }
}

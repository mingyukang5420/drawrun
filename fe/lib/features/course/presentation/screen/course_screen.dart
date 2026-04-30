import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:running/features/course/data/course_remote_datasource.dart';
import 'package:running/features/course/data/course_repository_impl.dart';
import 'package:running/features/course/presentation/course_viewmodel.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';
import 'package:running/shared/network/dio_client.dart';

// 코스 목록 화면
// 서버에서 코스를 불러와 목록으로 표시하고, 삭제 및 편집 화면 이동을 제공
class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // 화면 진입 시 ViewModel 생성 + 즉시 목록 로드
      create: (_) {
        final datasource = CourseRemoteDatasource(DioClient.create());
        return CourseViewModel(CourseRepositoryImpl(datasource))..loadCourses();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('코스')),

        body: Consumer<CourseViewModel>(
          builder: (context, vm, _) {
            // 로딩 중 표시
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // 오류 발생 시 메시지 표시
            if (vm.errorMessage != null) {
              return Center(child: Text(vm.errorMessage!));
            }

            // 저장된 코스가 없을 때
            if (vm.courses.isEmpty) {
              return const Center(child: Text('저장된 코스가 없습니다'));
            }

            // 코스 목록 표시
            return ListView.builder(
              itemCount: vm.courses.length,
              itemBuilder: (context, index) {
                final course = vm.courses[index];
                return ListTile(
                  title: Text(course.name),
                  subtitle: Text(
                    '${course.distanceKm.toStringAsFixed(2)} km',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: course.id != null
                        ? () => vm.deleteCourse(course.id!)
                        : null,
                  ),
                );
              },
            );
          },
        ),

        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CourseEditorScreen(),
                ),
              ).then((_) {
                // 편집 화면에서 돌아왔을 때 목록 새로고침
                if (context.mounted) {
                  context.read<CourseViewModel>().loadCourses();
                }
              });
            },
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}

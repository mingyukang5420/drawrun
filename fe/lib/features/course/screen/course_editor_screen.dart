import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:running/features/course/controller/course_controller.dart';
import 'package:running/features/course/widgets/course_map_view.dart';

class CourseEditorScreen extends StatelessWidget {
  const CourseEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CourseController(),
      child: Scaffold(
        appBar: AppBar(title: const Text('코스 생성')),

        body: const CourseMapView(),

        floatingActionButton: Consumer<CourseController>(
          builder: (context, controller, _) {
            return FloatingActionButton(
              onPressed: controller.clear,
              child: const Icon(Icons.refresh),
            );
          },
        ),
      ),
    );
  }
}
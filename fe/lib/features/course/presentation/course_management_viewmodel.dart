import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/shared/network/api_exception.dart';

class CourseManagementState {
  final List<Course> courses;
  final bool isLoading;
  final String? errorMessage;
  final CourseStatus selectedStatus;

  const CourseManagementState({
    this.courses = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedStatus = CourseStatus.all,
  });

  CourseManagementState copyWith({
    List<Course>? courses,
    bool? isLoading,
    String? errorMessage,
    CourseStatus? selectedStatus,
  }) =>
      CourseManagementState(
        courses: courses ?? this.courses,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
        selectedStatus: selectedStatus ?? this.selectedStatus,
      );
}

class CourseManagementNotifier extends Notifier<CourseManagementState> {
  final CourseRepository _repository;

  CourseManagementNotifier(this._repository);

  @override
  CourseManagementState build() {
    Future.microtask(() => loadMyCourses());
    return const CourseManagementState();
  }

  Future<void> loadMyCourses() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final courses =
          await _repository.getMyCourses(state.selectedStatus);
      state = state.copyWith(courses: courses, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  // 필터 칩 선택 시: 상태 변경 후 즉시 재조회
  Future<void> selectStatus(CourseStatus status) async {
    if (state.selectedStatus == status) return;
    state = state.copyWith(selectedStatus: status);
    await loadMyCourses();
  }

  Future<void> deleteCourse(int id) async {
    try {
      await _repository.deleteCourse(id);
      await loadMyCourses();
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    }
  }
}

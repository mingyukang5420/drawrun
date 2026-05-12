import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/shared/network/api_exception.dart';

class CourseManagementState {
  final List<Course> courses;
  final List<CourseDraft> drafts;
  final bool isLoading;
  final String? errorMessage;
  final CourseStatus selectedStatus;

  const CourseManagementState({
    this.courses = const [],
    this.drafts = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedStatus = CourseStatus.all,
  });

  CourseManagementState copyWith({
    List<Course>? courses,
    List<CourseDraft>? drafts,
    bool? isLoading,
    String? errorMessage,
    CourseStatus? selectedStatus,
  }) =>
      CourseManagementState(
        courses: courses ?? this.courses,
        drafts: drafts ?? this.drafts,
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
      if (state.selectedStatus == CourseStatus.ready) {
        final drafts = await _repository.getEditorDrafts();
        state = state.copyWith(drafts: drafts, isLoading: false);
      } else {
        final courses = await _repository.getMyCourses(state.selectedStatus);
        state = state.copyWith(courses: courses, isLoading: false);
      }
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

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

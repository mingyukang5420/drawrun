import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/shared/network/api_exception.dart';

class CourseManagementState {
  final List<CourseDraft> drafts;
  final bool isLoading;
  final String? errorMessage;
  // 현재 선택된 난이도 탭: 'EASY' | 'HARD' (null 이면 전체)
  final String? selectedDifficulty;

  const CourseManagementState({
    this.drafts = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedDifficulty,
  });

  // 선택된 난이도로 클라이언트 측 필터링한 목록
  List<CourseDraft> get filtered => selectedDifficulty == null
      ? drafts
      : drafts
          .where((d) => d.difficulty?.toUpperCase() == selectedDifficulty)
          .toList();

  CourseManagementState copyWith({
    List<CourseDraft>? drafts,
    bool? isLoading,
    String? errorMessage,
    String? selectedDifficulty,
  }) =>
      CourseManagementState(
        drafts: drafts ?? this.drafts,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
        selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
      );
}

class CourseManagementNotifier extends Notifier<CourseManagementState> {
  final CourseRepository _repository;

  CourseManagementNotifier(this._repository);

  @override
  CourseManagementState build() {
    // 초기 로드는 화면의 initState 에서 init() 을 호출해 처리한다
    return const CourseManagementState();
  }

  Future<void> loadMyCourses({int page = 0}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 챌린지 소속 코스 목록 API 사용 (GET /api/v1/editor/challenge?page=)
      final drafts = await _repository.getChallengeCourses(page: page);
      state = state.copyWith(drafts: drafts, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  // 난이도 탭 선택 — 서버 재요청 없이 클라이언트 필터만 교체
  void selectDifficulty(String? difficulty) {
    state = state.copyWith(selectedDifficulty: difficulty);
  }

  Future<void> deleteCourse(int id) async {
    await _repository.deleteCourse(id);
    await loadMyCourses();
  }
}

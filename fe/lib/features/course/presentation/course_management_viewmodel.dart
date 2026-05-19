import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/shared/network/api_exception.dart';

class CourseManagementState {
  final List<CourseDraft> drafts;
  final bool isLoading;
  final String? errorMessage;
  // 챌린지 제목 — result 레벨에서 파싱되어 화면 헤더에 표시
  final String? challengeTitle;

  const CourseManagementState({
    this.drafts = const [],
    this.isLoading = false,
    this.errorMessage,
    this.challengeTitle,
  });

  // challengeDifficulty 기준으로 난이도별 목록 반환 (탭 필터링은 UI 레벨에서 처리)
  List<CourseDraft> byDifficulty(String difficulty) => drafts
      .where((d) => d.challengeDifficulty?.toUpperCase() == difficulty)
      .toList();

  CourseManagementState copyWith({
    List<CourseDraft>? drafts,
    bool? isLoading,
    String? errorMessage,
    String? challengeTitle,
  }) =>
      CourseManagementState(
        drafts: drafts ?? this.drafts,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
        challengeTitle: challengeTitle ?? this.challengeTitle,
      );
}

class CourseManagementNotifier extends Notifier<CourseManagementState> {
  final CourseRepository _repository;

  CourseManagementNotifier(this._repository);

  @override
  CourseManagementState build() {
    // 초기 로드는 화면의 initState 에서 처리한다
    return const CourseManagementState();
  }

  Future<void> loadMyCourses({int page = 0}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 챌린지 코스 API 호출 — (코스 목록, 챌린지 제목) 레코드 반환
      final (drafts, challengeTitle) =
          await _repository.getChallengeCourses(page: page);
      state = state.copyWith(
        drafts: drafts,
        challengeTitle: challengeTitle,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  Future<void> deleteCourse(int id) async {
    await _repository.deleteCourse(id);
    await loadMyCourses();
  }
}

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
  // 챌린지 제목 — result 레벨에서 파싱되어 화면 헤더에 표시
  final String? challengeTitle;

  const CourseManagementState({
    this.drafts = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedDifficulty,
    this.challengeTitle,
  });

  // challengeDifficulty 기준으로 클라이언트 측 필터링
  // (difficulty 는 에디터 코스 난이도, challengeDifficulty 가 챌린지 자체 난이도)
  List<CourseDraft> get filtered => selectedDifficulty == null
      ? drafts
      : drafts
          .where((d) =>
              d.challengeDifficulty?.toUpperCase() == selectedDifficulty)
          .toList();

  CourseManagementState copyWith({
    List<CourseDraft>? drafts,
    bool? isLoading,
    String? errorMessage,
    String? selectedDifficulty,
    String? challengeTitle,
  }) =>
      CourseManagementState(
        drafts: drafts ?? this.drafts,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
        selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
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

  // 난이도 탭 선택 — 서버 재요청 없이 클라이언트 필터만 교체
  // 이미 선택된 탭을 다시 누르면 null (전체 보기)로 토글
  void selectDifficulty(String difficulty) {
    final next = state.selectedDifficulty == difficulty ? null : difficulty;
    state = state.copyWith(selectedDifficulty: next);
  }

  Future<void> deleteCourse(int id) async {
    await _repository.deleteCourse(id);
    await loadMyCourses();
  }
}

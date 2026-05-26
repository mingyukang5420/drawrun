import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/bookmark/domain/bookmark_repository.dart';
import 'package:running/features/course/domain/course.dart';
import 'package:running/shared/network/api_exception.dart';

// 러닝 메인 화면 상단 캐러셀 (최대 5장) 전용 상태.
//
// 북마크 목록 화면이 쓰는 ViewModel(BookmarkListNotifier) 과는 별도다.
// 캐러셀은 첫 페이지만, size=5 로 한 번만 받으므로 페이지네이션이 없다.
class BookmarkedCoursesState {
  // 최신 5개 북마크. 첫 진입 전에는 빈 리스트.
  final List<Course> courses;

  // 첫 진입 시 true → 카드 자리에 스피너를 그릴지 위에서 결정할 때 사용.
  final bool isLoading;

  // 에러 메시지. 비어 있어도 카드 영역은 보이지만 사용자가 다시 시도하기 어려움 →
  // 그래서 화면 코드에서 작은 retry 버튼을 같이 그린다.
  final String? errorMessage;

  const BookmarkedCoursesState({
    this.courses = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  BookmarkedCoursesState copyWith({
    List<Course>? courses,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BookmarkedCoursesState(
      courses: courses ?? this.courses,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// 러닝 화면 상단 캐러셀 전용 Notifier.
//
// build() 단계에서 곧장 load() 를 microtask 로 트리거 — 화면이 첫 build 되면
// 바로 데이터 요청이 나간다 (CourseNotifier 의 autoLoad 패턴과 동일).
class BookmarkedCoursesNotifier extends Notifier<BookmarkedCoursesState> {
  final BookmarkRepository _repository;

  BookmarkedCoursesNotifier(this._repository);

  @override
  BookmarkedCoursesState build() {
    // build() 가 동기 반환 후 비동기 로드를 시작.
    Future.microtask(load);
    return const BookmarkedCoursesState(isLoading: true);
  }

  // BE 에서 최신 5개 북마크를 받아 상태에 반영.
  // 5개를 size 로 하고 page=0 만 본다 (캐러셀은 첫 5개만 필요).
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.getMyBookmarks(page: 0, size: 5);
      state = state.copyWith(courses: page.courses, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }
}
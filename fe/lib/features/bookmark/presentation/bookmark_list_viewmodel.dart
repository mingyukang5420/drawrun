import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/bookmark/domain/bookmark_repository.dart';
import 'package:running/features/course/domain/course.dart';
import 'package:running/shared/network/api_exception.dart';

// 북마크 목록 화면이 들고 있는 상태. ( 무한 스크롤 )
class BookmarkListState {
  // 지금까지 누적된 북마크 코스 (page 0..현재 까지의 합).
  final List<Course> courses;

  // 다음 페이지가 있는지 — 무한스크롤 트리거 조건.
  final bool hasNext;

  // 다음 페이지를 요청해야 할 때 사용할 page 인덱스 (다음에 요청할 페이지 번호).
  final int nextPage;

  // 첫 로드 중인지 — 화면 가운데 스피너용.
  final bool isLoadingInitial;

  // 다음 페이지 로드 중인지 — 리스트 끝에 작은 스피너 한 줄 표시용.
  final bool isLoadingMore;

  // 에러 메시지. 첫 로드 / 추가 로드 둘 다 같은 슬롯을 쓴다.
  final String? errorMessage;

  const BookmarkListState({
    this.courses = const [],
    this.hasNext = true,
    this.nextPage = 0,
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  BookmarkListState copyWith({
    List<Course>? courses,
    bool? hasNext,
    int? nextPage,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BookmarkListState(
      courses: courses ?? this.courses,
      hasNext: hasNext ?? this.hasNext,
      nextPage: nextPage ?? this.nextPage,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// 북마크 목록 화면 Notifier.
//
// build() 단계에서 첫 페이지를 비동기로 로드한다.
// loadMore() 는 화면이 끝 부근에 도달했을 때 호출하면 다음 페이지를 누적해 받아온다.
// refresh() 는 pull-to-refresh 핸들러로 사용된다 — 상태를 처음으로 되돌리고 page=0 부터 다시.
class BookmarkListNotifier extends Notifier<BookmarkListState> {
  final BookmarkRepository _repository;

  // 한 페이지당 받을 항목 수. BE 기본값(10) 보다 좀 더 받아 와 스크롤이 자주 멈추지 않게.
  static const _pageSize = 20;

  BookmarkListNotifier(this._repository);

  @override
  BookmarkListState build() {
    Future.microtask(_loadInitial);
    return const BookmarkListState(isLoadingInitial: true);
  }

  // 첫 페이지 로드.
  Future<void> _loadInitial() async {
    state = state.copyWith(isLoadingInitial: true, clearError: true);
    try {
      final page = await _repository.getMyBookmarks(page: 0, size: _pageSize);
      state = state.copyWith(
        courses: page.courses,
        hasNext: page.hasNext,
        nextPage: 1,
        isLoadingInitial: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoadingInitial: false,
        errorMessage: e.message,
      );
    }
  }

  // 다음 페이지 로드 (누적).
  // hasNext=false 거나 이미 로딩 중이면 호출을 무시한다.
  Future<void> loadMore() async {
    if (!state.hasNext) return;
    if (state.isLoadingMore || state.isLoadingInitial) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repository.getMyBookmarks(
        page: state.nextPage,
        size: _pageSize,
      );
      state = state.copyWith(
        // 기존 목록 뒤에 새 페이지의 코스들을 이어 붙인다.
        courses: [...state.courses, ...page.courses],
        hasNext: page.hasNext,
        nextPage: state.nextPage + 1,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.message,
      );
    }
  }

  // 당겨서 새로고침 핸들러. 처음부터 다시 받아 누적 결과를 초기화한다.
  Future<void> refresh() async {
    state = const BookmarkListState(isLoadingInitial: true);
    await _loadInitial();
  }

  // 로컬 리스트에서 한 코스를 즉시 제거한다.
  //
  // 사용자가 행의 북마크 아이콘으로 북마크를 해제했을 때,
  // 전체 페이지를 다시 받지 않고 그 한 행만 사라지게 하기 위한 진입점.
  // BE 호출은 호출자(= bookmarkedCourseIdsProvider.toggle)가 이미 끝낸 상태로 가정한다 —
  // 이 메서드는 순수 로컬 상태 갱신.
  void removeCourseLocally(int courseId) {
    state = state.copyWith(
      // 새 리스트를 만들어야 Riverpod 가 변경을 인식한다.
      // (in-place 로 list.remove() 하면 같은 참조라 변경 감지 못 함.)
      courses: state.courses.where((c) => c.id != courseId).toList(),
    );
  }
}
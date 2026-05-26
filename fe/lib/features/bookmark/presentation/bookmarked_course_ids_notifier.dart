import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/bookmark/domain/bookmark_repository.dart';
import 'package:running/features/bookmark/presentation/bookmark_provider.dart';
import 'package:running/shared/network/api_exception.dart';

// 북마크된 코스 ID 집합 캐시의 상태.
//
// 카드 위젯이 이 상태를 watch 해서 "내가 이 코스를 북마크했나" 를 즉시 판정한다.
// 별도 ViewModel 이 아니라 앱 전역에서 쓰이는 작은 캐시이므로 *Notifier 라는 이름을 쓴다.
class BookmarkedCourseIdsState {
  // 사용자가 북마크한 코스의 ID 집합. 첫 로드 전엔 비어 있다.
  final Set<int> ids;

  // 첫 로드 중인지 — 카드 위젯에서 "아직 모름" 상태일 때 회색 아이콘으로 가리는 데 사용.
  final bool isLoading;

  // 토글 실패 시 화면에 노출할 메시지. null 이면 정상.
  // (성공 시에는 SnackBar 없이 조용히 업데이트만 한다.)
  final String? errorMessage;

  const BookmarkedCourseIdsState({
    this.ids = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  BookmarkedCourseIdsState copyWith({
    Set<int>? ids,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BookmarkedCourseIdsState(
      ids: ids ?? this.ids,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// 북마크된 코스 ID 집합을 관리하는 Notifier.
//
// 책임:
//  1) 첫 빌드 시 BE 에서 사용자의 모든 북마크 코스를 받아 ID 만 추출, Set 으로 저장.
//  2) UI 가 `state.ids.contains(courseId)` 로 판정.
//  3) toggle(courseId) 호출 시 낙관적 업데이트 + BE POST/DELETE + 실패 시 복구.
//  4) 토글 성공 후 러닝 캐러셀(bookmarkedCoursesProvider) invalidate — 다음 빌드에서 새 데이터를 받게.
class BookmarkedCourseIdsNotifier
    extends Notifier<BookmarkedCourseIdsState> {
  final BookmarkRepository _repository;

  // 동일 코스의 토글이 동시에 두 번 들어오는 사고를 막는 가드.
  // (사용자가 빠르게 두 번 탭하면 add 와 remove 가 동시에 날아갈 위험 — Set 한 번에 한 ID 만 토글되도록 잠금.)
  final Set<int> _toggling = {};

  BookmarkedCourseIdsNotifier(this._repository);

  @override
  BookmarkedCourseIdsState build() {
    // build() 가 동기 반환 후 비동기 로드 시작.
    Future.microtask(_loadAll);
    return const BookmarkedCourseIdsState(isLoading: true);
  }

  // 사용자의 모든 북마크 코스 ID 를 받아 Set 에 채운다.
  // hasNext 가 false 가 될 때까지 페이지를 끝까지 받는다.
  // size 를 100 으로 잡아 대부분의 사용자는 한 번에 끝남.
  Future<void> _loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ids = <int>{};
      int page = 0;
      const pageSize = 100;
      while (true) {
        final result = await _repository.getMyBookmarks(
          page: page,
          size: pageSize,
        );
        for (final c in result.courses) {
          if (c.id != null) ids.add(c.id!);
        }
        if (!result.hasNext) break;
        page += 1;
      }
      state = state.copyWith(ids: ids, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  // 한 코스의 북마크를 토글한다.
  //
  // 흐름:
  //   1) 같은 ID 가 이미 토글 중이면 호출 무시 (더블탭 가드).
  //   2) 현재 상태(포함 여부) 에 따라 add 할지 remove 할지 결정.
  //   3) 낙관적으로 로컬 Set 을 먼저 뒤집어 화면을 즉시 갱신.
  //   4) BE POST/DELETE 호출.
  //   5) 성공: 러닝 캐러셀 invalidate — 다음 빌드에서 새 데이터로 채워짐.
  //   6) 실패: 로컬 Set 을 원래대로 되돌리고 errorMessage 노출.
  Future<void> toggle(int courseId) async {
    if (_toggling.contains(courseId)) return;
    _toggling.add(courseId);
    try {
      final wasBookmarked = state.ids.contains(courseId);

      // 낙관적 업데이트.
      // {...state.ids} 로 새 Set 을 만들어야 Riverpod 가 상태 변경을 인식한다.
      // (state 의 ids 를 in-place 로 수정하면 같은 참조라 변경 감지 못 함.)
      final optimistic = {...state.ids};
      if (wasBookmarked) {
        optimistic.remove(courseId);
      } else {
        optimistic.add(courseId);
      }
      state = state.copyWith(ids: optimistic, clearError: true);

      try {
        if (wasBookmarked) {
          await _repository.removeBookmark(courseId);
        } else {
          await _repository.addBookmark(courseId);
        }
        // 러닝 캐러셀(5장) 도 같은 데이터의 다른 슬라이스를 들고 있다.
        // 사용자가 코스 탐색에서 북마크를 끄거나 켰을 때, 다음에 러닝 탭을 열면
        // 캐러셀이 새 데이터를 보여주도록 캐시를 무효화.
        ref.invalidate(bookmarkedCoursesProvider);
      } on ApiException catch (e) {
        // 실패: 낙관적 변경 되돌리기.
        final revert = {...state.ids};
        if (wasBookmarked) {
          revert.add(courseId);
        } else {
          revert.remove(courseId);
        }
        state = state.copyWith(ids: revert, errorMessage: e.message);
      }
    } finally {
      _toggling.remove(courseId);
    }
  }
}
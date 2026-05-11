import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/domain/record_repository.dart';
import 'package:running/features/record/domain/record_summary.dart';
import 'package:running/shared/network/api_exception.dart';

// 히스토리 화면이 구독하는 불변 상태.
//
// "지금까지 로드된 카드 전체 목록(items)" + "더 불러올 수 있는지(hasNext)" + "지금 추가 로딩 중인지(isLoadingMore)"
// 세 가지를 한 자리에서 관리한다.
class RecordHistoryState {
  // 지금까지 누적해서 받은 카드 목록.
  // 새 페이지 응답이 도착하면 List.from(items)..addAll(newItems) 로 합친다.
  final List<RecordSummary> items;

  // BE 가 알려주는 "다음 페이지 존재 여부".
  // false 면 스크롤이 끝까지 가도 더 이상 fetchSummaries 를 호출하지 않는다.
  final bool hasNext;

  // 첫 페이지 로딩 중인지 — 화면 전체에 CircularProgressIndicator 를 보일지 결정.
  final bool isInitialLoading;

  // 두 번째 이후 페이지 로딩 중인지 — 리스트 맨 아래에 작은 스피너를 보일지 결정.
  final bool isLoadingMore;

  // 다음 페이지 요청 시 보낼 page 번호.
  // 첫 페이지가 끝나면 1, 두 번째 페이지가 끝나면 2 ... 식으로 누적.
  final int nextPage;

  // 사용자에게 보여줄 에러 메시지. null 이면 정상.
  final String? errorMessage;

  const RecordHistoryState({
    this.items = const [],
    this.hasNext = true,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.nextPage = 0,
    this.errorMessage,
  });

  RecordHistoryState copyWith({
    List<RecordSummary>? items,
    bool? hasNext,
    bool? isInitialLoading,
    bool? isLoadingMore,
    int? nextPage,
    String? errorMessage,
    // 에러 메시지를 null 로 비우고 싶을 때(다시 시도 등) errorMessage 만으로는
    // null/유지 구분이 안 되므로 별도 플래그를 받는다.
    bool clearError = false,
  }) {
    return RecordHistoryState(
      items: items ?? this.items,
      hasNext: hasNext ?? this.hasNext,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextPage: nextPage ?? this.nextPage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// 히스토리 화면 Notifier.
//
// 화면 진입 시 build() → 즉시 첫 페이지 로드.
// 사용자가 스크롤로 끝에 닿으면 loadMore() 가 호출되어 다음 페이지를 이어 받는다.
class RecordHistoryNotifier extends Notifier<RecordHistoryState> {
  final RecordRepository _repository;

  RecordHistoryNotifier(this._repository);

  @override
  RecordHistoryState build() {
    // 화면이 처음 그려진 직후 비동기로 첫 페이지를 불러온다.
    // build() 안에서 await 을 쓸 수 없으므로 microtask 로 한 단계 빼낸다.
    Future.microtask(refresh);
    return const RecordHistoryState(isInitialLoading: true);
  }

  // 처음부터 다시 불러오기 (당겨서 새로고침 / 에러 후 재시도).
  // page=0 으로 리셋한 뒤 한 페이지를 받는다.
  Future<void> refresh() async {
    state = state.copyWith(
      items: const [],
      hasNext: true,
      isInitialLoading: true,
      isLoadingMore: false,
      nextPage: 0,
      clearError: true,
    );
    await _loadPage(0);
  }

  // 다음 페이지를 이어서 불러오기.
  // - hasNext == false: 더 가져올 게 없으니 아무것도 안 한다.
  // - 이미 로딩 중: 중복 호출 방지.
  Future<void> loadMore() async {
    if (!state.hasNext) return;
    if (state.isLoadingMore || state.isInitialLoading) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    await _loadPage(state.nextPage);
  }

  // 실제 HTTP 호출 + 상태 머지.
  // 첫 페이지(page == 0) 와 추가 페이지(page > 0) 모두 이 함수를 통한다.
  Future<void> _loadPage(int page) async {
    try {
      final result = await _repository.getSummaries(page: page);

      // page == 0 이면 새로 시작이므로 그대로 대입.
      // 그 외에는 기존 items 뒤에 이어붙인다.
      final merged = page == 0
          ? result.items
          : <RecordSummary>[...state.items, ...result.items];

      state = state.copyWith(
        items: merged,
        hasNext: result.hasNext,
        isInitialLoading: false,
        isLoadingMore: false,
        // 다음 호출 시 보낼 페이지 번호 = 이번에 받은 page + 1.
        nextPage: result.page + 1,
        clearError: true,
      );
    } on ApiException catch (e) {
      // 첫 페이지 실패면 빈 리스트 + 에러 메시지로 떨어뜨려 사용자에게 재시도 버튼 제공.
      // 추가 페이지 실패면 기존 데이터는 보존하고 에러 메시지만 갱신.
      state = state.copyWith(
        isInitialLoading: false,
        isLoadingMore: false,
        errorMessage: e.message,
      );
    }
  }
}
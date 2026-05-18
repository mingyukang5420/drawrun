import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/challenge/domain/challenge_list.dart';
import 'package:running/features/challenge/domain/challenge_repository.dart';
import 'package:running/shared/network/api_exception.dart';

// 홈 화면 챌린지 카드 두 장을 위한 상태.
//
// 비동기 데이터(GET /v1/challenge) 로딩/성공/에러 세 상태를 단일 객체로 표현.
// 다른 도메인의 ViewModel(예: BookmarkedCoursesNotifier) 과 같은 형태 — isLoading + errorMessage + payload.
class ChallengeListState {
  // 서버에서 받은 챌린지 묶음. 첫 진입 전에는 null.
  final ChallengeList? list;

  // 첫 진입 시 true → 카드에 placeholder 를 보여 줄지 위에서 결정.
  final bool isLoading;

  // 에러 메시지. 비어 있어도 카드는 보이지만 사용자가 다시 시도하기 어려움 →
  // 본 화면에선 카드 본문이 작아 별도 에러 UI 를 두지 않고 placeholder 유지.
  final String? errorMessage;

  const ChallengeListState({
    this.list,
    this.isLoading = false,
    this.errorMessage,
  });

  ChallengeListState copyWith({
    ChallengeList? list,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChallengeListState(
      list: list ?? this.list,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// 홈 화면 챌린지 카드 두 장 전용 Notifier.
//
// build() 단계에서 곧장 load() 를 microtask 로 트리거 — 화면이 첫 build 되면
// 바로 데이터 요청이 나간다 (BookmarkedCoursesNotifier 와 동일한 패턴).
class ChallengeListNotifier extends Notifier<ChallengeListState> {
  final ChallengeRepository _repository;

  ChallengeListNotifier(this._repository);

  @override
  ChallengeListState build() {
    // build() 가 동기 반환 후 비동기 로드를 시작.
    Future.microtask(load);
    return const ChallengeListState(isLoading: true);
  }

  // BE 에서 Easy/Hard 챌린지 한 쌍을 받아 상태에 반영.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repository.getChallengeList();
      state = state.copyWith(list: list, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  // 사용자 액션(Pull to refresh 등) 에서 강제 새로고침이 필요할 때 호출.
  Future<void> refresh() => load();
}

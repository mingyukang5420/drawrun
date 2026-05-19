import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/ranking/domain/participated_challenge_group.dart';
import 'package:running/features/ranking/domain/ranking_repository.dart';
import 'package:running/shared/network/api_exception.dart';

// 랭킹 화면 진입 시 한 번만 호출되는 "참여 챌린지 목록" 상태.
//
// 비동기 데이터(GET /v1/challenge/participated) 의 로딩 / 성공 / 에러 세 상태를
// 단일 객체로 표현. 챌린지 도메인의 ChallengeListState 와 같은 형태 —
// payload + isLoading + errorMessage.
class ParticipatedListState {
  // 서버에서 받은 참여 챌린지 묶음 목록. 첫 진입 전에는 null.
  // 받아 온 결과가 빈 배열일 수도 있음(참여 챌린지 0개) — 빈 리스트와 null 은 구분된다.
  final List<ParticipatedChallengeGroup>? groups;

  // 첫 진입 시 true → 화면에 로딩 인디케이터를 띄울지 위에서 결정.
  final bool isLoading;

  // 에러 메시지 — 있으면 화면이 재시도 안내를 띄울 수 있다.
  final String? errorMessage;

  const ParticipatedListState({
    this.groups,
    this.isLoading = false,
    this.errorMessage,
  });

  ParticipatedListState copyWith({
    List<ParticipatedChallengeGroup>? groups,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ParticipatedListState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// 참여 챌린지 목록을 한 번 받아 들고 있다가 화면에 흘려주는 Notifier.
//
// build() 가 동기 반환 직후 Future.microtask 로 load() 를 트리거 —
// 화면이 첫 build 되면 바로 데이터 요청이 나간다 (ChallengeListNotifier 와 동일 패턴).
class ParticipatedNotifier extends Notifier<ParticipatedListState> {
  final RankingRepository _repository;

  ParticipatedNotifier(this._repository);

  @override
  ParticipatedListState build() {
    // build() 가 동기 반환 후 비동기 로드를 시작.
    Future.microtask(load);
    return const ParticipatedListState(isLoading: true);
  }

  // BE 에서 참여 챌린지 목록을 받아 상태에 반영.
  // 빈 배열로 와도 errorMessage 는 비워 둔다 — "참여 챌린지 없음" 빈 상태는
  // groups.isEmpty 로 화면이 분기하면 된다.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final groups = await _repository.getParticipatedGroups();
      state = state.copyWith(groups: groups, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  // 사용자 액션(Pull to refresh 등) 에서 강제 새로고침이 필요할 때 호출.
  Future<void> refresh() => load();
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/ranking/domain/challenge_ranking.dart';
import 'package:running/features/ranking/domain/ranking_repository.dart';
import 'package:running/shared/network/api_exception.dart';

// 챌린지 랭킹 화면 상태.
//
// 한 화면에서 사용자가 Easy / Hard 두 탭을 동시에 보거나, 시트로 챌린지를
// 갈아끼우면서 여러 challengeId 의 랭킹을 짧은 시간 안에 요청할 수 있다.
// 그래서 challengeId 별로 캐시 / 로딩 / 에러를 분리 보관한다 —
// "8번 챌린지 결과", "12번 챌린지 결과" 가 서로의 상태를 덮어쓰지 않는다.
//
// flutter_riverpod 3.3.x 의 수동 API 는 FamilyNotifier 를 제공하지 않아
// 단일 Notifier 안에서 Map 으로 family 효과를 직접 흉내내는 패턴이다.
class ChallengeRankingState {
  // challengeId -> 응답 본체. 한번 받아오면 캐시에 남아 같은 화면 안에서 재요청 없이 즉시 표시.
  final Map<int, ChallengeRanking> rankings;

  // challengeId -> 에러 메시지. null 이거나 키가 없으면 정상 / 미요청.
  final Map<int, String> errors;

  // 현재 in-flight 인 challengeId 들. 같은 ID 가 중복 호출되지 않도록 가드 용도.
  final Set<int> loadingIds;

  const ChallengeRankingState({
    this.rankings = const {},
    this.errors = const {},
    this.loadingIds = const {},
  });

  // 특정 challengeId 의 응답을 꺼낸다. 아직 도착 전이면 null.
  ChallengeRanking? rankingFor(int challengeId) => rankings[challengeId];

  // 특정 challengeId 가 현재 로딩 중인지.
  bool isLoading(int challengeId) => loadingIds.contains(challengeId);

  // 특정 challengeId 의 에러 메시지. 없으면 null.
  String? errorFor(int challengeId) => errors[challengeId];

  ChallengeRankingState copyWith({
    Map<int, ChallengeRanking>? rankings,
    Map<int, String>? errors,
    Set<int>? loadingIds,
  }) {
    return ChallengeRankingState(
      rankings: rankings ?? this.rankings,
      errors: errors ?? this.errors,
      loadingIds: loadingIds ?? this.loadingIds,
    );
  }
}

// 챌린지 랭킹 Notifier.
//
// 한 인스턴스가 여러 challengeId 의 결과를 동시에 들고 있다 (위 State 의 Map 들).
// 화면(_ChallengeRankingTab) 은 build 시점에 자기 challengeId 로 loadIfNeeded() 를
// 호출하고, state 에서 자기 challengeId 의 값을 꺼내 분기 표시한다.
class ChallengeRankingNotifier extends Notifier<ChallengeRankingState> {
  final RankingRepository _repository;

  ChallengeRankingNotifier(this._repository);

  @override
  ChallengeRankingState build() => const ChallengeRankingState();

  // 이미 받아 둔 challengeId 면 아무 일도 하지 않는다 — 같은 화면에서 챌린지를
  // 바꿨다 돌아왔을 때 캐시 hit 으로 즉시 표시되도록 한다.
  // in-flight 인 challengeId 도 중복 호출 방지.
  Future<void> loadIfNeeded(int challengeId) async {
    if (state.rankings.containsKey(challengeId)) return;
    if (state.loadingIds.contains(challengeId)) return;
    await load(challengeId);
  }

  // 실제 호출. 사용자 "다시 시도" 버튼이 부르는 진입점이기도 하다.
  Future<void> load(int challengeId) async {
    // 로딩 시작 — 그 challengeId 만 loadingIds 에 추가, 다른 challengeId 상태는 그대로.
    state = state.copyWith(
      loadingIds: {...state.loadingIds, challengeId},
      errors: {...state.errors}..remove(challengeId),
    );

    try {
      final ranking = await _repository.getChallengeRanking(challengeId);
      state = state.copyWith(
        rankings: {...state.rankings, challengeId: ranking},
        loadingIds: {...state.loadingIds}..remove(challengeId),
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        loadingIds: {...state.loadingIds}..remove(challengeId),
        errors: {...state.errors, challengeId: e.message},
      );
    }
  }

  // 강제 새로고침 — 캐시 비우고 다시 받아온다.
  Future<void> refresh(int challengeId) async {
    state = state.copyWith(
      rankings: {...state.rankings}..remove(challengeId),
    );
    await load(challengeId);
  }
}

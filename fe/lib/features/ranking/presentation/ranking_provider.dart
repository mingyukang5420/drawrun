import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/ranking/data/ranking_remote_datasource.dart';
import 'package:running/features/ranking/data/ranking_repository_impl.dart';
import 'package:running/features/ranking/domain/my_challenge_detail.dart';
import 'package:running/features/ranking/domain/ranking_repository.dart';
import 'package:running/features/ranking/presentation/challenge_ranking_viewmodel.dart';
import 'package:running/features/ranking/presentation/participated_viewmodel.dart';
import 'package:running/shared/network/dio_client.dart';
import 'package:running/shared/network/dio_provider.dart';

// 랭킹 데이터소스 Provider.
// 앱 전역 dioProvider 를 주입받으므로 인증 인터셉터가 자동으로 적용된다.
final rankingRemoteDataSourceProvider = Provider<RankingRemoteDataSource>(
  (ref) => RankingRemoteDataSource(ref.watch(dioProvider)),
);

// 화면 코드에서 참조할 단 하나의 진입점.
// 인터페이스 타입(RankingRepository) 으로 노출해 구현체 교체가 자유롭다.
final rankingRepositoryProvider = Provider<RankingRepository>(
  (ref) => RankingRepositoryImpl(
    ref.watch(rankingRemoteDataSourceProvider),
  ),
);

// NotifierProvider 의 팩토리는 ref 를 받지 못하므로 Repository 를 직접 조립한다.
// 다른 도메인(record_provider 등) 과 동일한 패턴.
RankingRepository _rankingRepositoryFor() {
  return RankingRepositoryImpl(RankingRemoteDataSource(DioClient.create()));
}

// 참여 챌린지 목록 Notifier Provider.
//
// autoDispose: 랭킹 탭을 빠져나가면 자동 해제 → 다시 진입하면 새로 fetch.
final participatedViewModelProvider = NotifierProvider.autoDispose<
    ParticipatedNotifier, ParticipatedListState>(
  () => ParticipatedNotifier(_rankingRepositoryFor()),
);

// 챌린지 랭킹 Notifier Provider.
//
// 한 인스턴스가 challengeId 별 결과를 Map 으로 들고 있다 (state 내부 캐시).
// flutter_riverpod 3.3.x 의 수동 API 가 family + Notifier 조합을 제공하지 않아,
// FamilyNotifier 대신 단일 Notifier 안에서 ID 별 캐시를 들고 family 효과를 흉내낸다.
//
// autoDispose: 랭킹 탭을 빠져나가면 캐시 전체가 자동 해제 → 다시 진입하면 새로 fetch.
final challengeRankingViewModelProvider = NotifierProvider.autoDispose<
    ChallengeRankingNotifier, ChallengeRankingState>(
  () => ChallengeRankingNotifier(_rankingRepositoryFor()),
);

// 본인의 챌린지 상세 조회 Provider.
//
// FutureProvider.family.autoDispose 패턴으로 challengeId 마다 별개 호출.
// 화면(MyChallengeDetailScreen) 이 한 번만 watch 해서 결과를 표시한다.
// autoDispose: 상세 화면 닫으면 자동 해제 - 다시 들어오면 새로 fetch.
final myChallengeDetailProvider =
    FutureProvider.autoDispose.family<MyChallengeDetail, int>(
  (ref, challengeId) async {
    final repository = _rankingRepositoryFor();
    return repository.getMyChallengeDetail(challengeId);
  },
);

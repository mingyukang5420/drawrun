import 'package:running/features/ranking/data/ranking_remote_datasource.dart';
import 'package:running/features/ranking/domain/challenge_ranking.dart';
import 'package:running/features/ranking/domain/my_challenge_detail.dart';
import 'package:running/features/ranking/domain/participated_challenge_group.dart';
import 'package:running/features/ranking/domain/ranking_repository.dart';

// RankingRepository 인터페이스의 구체 구현.
//
// 지금은 remote datasource 한 개만 의존하므로 메서드들이 1:1 위임 형태.
// (로컬 캐시가 생긴다면 이 클래스 안에서 remote / local 조합이 추가된다.)
class RankingRepositoryImpl implements RankingRepository {
  final RankingRemoteDataSource _remote;

  RankingRepositoryImpl(this._remote);

  @override
  Future<List<ParticipatedChallengeGroup>> getParticipatedGroups() =>
      _remote.fetchParticipatedGroups();

  @override
  Future<ChallengeRanking> getChallengeRanking(int challengeId) =>
      _remote.fetchChallengeRanking(challengeId);

  @override
  Future<MyChallengeDetail> getMyChallengeDetail(int challengeId) =>
      _remote.fetchMyChallengeDetail(challengeId);
}

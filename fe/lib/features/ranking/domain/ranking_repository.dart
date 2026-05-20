import 'package:running/features/ranking/domain/challenge_ranking.dart';
import 'package:running/features/ranking/domain/participated_challenge_group.dart';

// 랭킹 도메인의 Repository 계약.
//
// Presentation 계층(Notifier / Provider) 은 이 인터페이스만 참조하고,
// 실제 구현체(RankingRepositoryImpl) 는 data 레이어에서 주입받는다.
// dio 같은 외부 라이브러리 타입이 여기에 등장하면 안 된다.
abstract class RankingRepository {
  // 내가 참여한 챌린지 목록 조회 — 시트(슬라이드) 에 그대로 노출되는 데이터.
  //
  // 한 항목 = 한 챌린지(주차) 안의 Easy / Hard 두 코스 ID 묶음.
  // 참여한 챌린지가 없으면 빈 리스트로 옴.
  Future<List<ParticipatedChallengeGroup>> getParticipatedGroups();

  // 한 챌린지(한 난이도) 의 랭킹 조회.
  //
  // Easy 탭이 보이면 group.easyChallengeId, Hard 탭이 보이면 group.hardChallengeId 로 호출한다.
  // 인증 토큰은 dio 인터셉터에서 자동으로 붙는다.
  Future<ChallengeRanking> getChallengeRanking(int challengeId);
}

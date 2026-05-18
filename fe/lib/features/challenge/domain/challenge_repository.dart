import 'package:running/features/challenge/domain/challenge_list.dart';

// 챌린지 도메인의 Repository 계약.
//
// Presentation 계층(ViewModel/Notifier) 은 이 인터페이스만 참조하고,
// 실제 구현체(ChallengeRepositoryImpl) 는 data 레이어에서 주입받는다.
// dio 같은 외부 라이브러리 타입이 여기에 등장하면 안 된다.
abstract class ChallengeRepository {
  // 현재 노출 가능한 Easy/Hard 챌린지 목록을 한 번에 조회.
  //
  // 인증 토큰이 dio 인터셉터에서 자동으로 붙어 BE 가 본인 베스트 순위까지 채워 내려준다.
  // 한 번도 참여한 적 없는 챌린지면 myBestRank / myBestSimilarityScore 가 null 인 채로 도착.
  Future<ChallengeList> getChallengeList();
}

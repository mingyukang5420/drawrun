import 'package:running/features/challenge/data/challenge_remote_datasource.dart';
import 'package:running/features/challenge/domain/challenge_list.dart';
import 'package:running/features/challenge/domain/challenge_repository.dart';

// ChallengeRepository 인터페이스의 구체 구현.
//
// 지금은 remote datasource 한 개만 의존하므로 메서드들이 1:1 위임 형태.
// (로컬 캐시가 생긴다면 이 클래스 안에서 remote/local 조합이 추가된다.)
class ChallengeRepositoryImpl implements ChallengeRepository {
  final ChallengeRemoteDataSource _remote;

  ChallengeRepositoryImpl(this._remote);

  @override
  Future<ChallengeList> getChallengeList() => _remote.fetchChallengeList();
}

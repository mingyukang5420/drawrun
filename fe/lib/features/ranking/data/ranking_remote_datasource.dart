import 'package:dio/dio.dart';

import 'package:running/features/ranking/domain/challenge_ranking.dart';
import 'package:running/features/ranking/domain/my_challenge_detail.dart';
import 'package:running/features/ranking/domain/participated_challenge_group.dart';
import 'package:running/shared/network/api_exception.dart';

// 랭킹 관련 HTTP 요청 전담 클래스.
//
// 책임:
//  - 정해진 엔드포인트로 dio 요청을 던진다.
//  - 응답 envelope({ isSuccess, result, ... }) 을 풀어 result 안의 데이터를 도메인 객체로 변환.
//  - DioException -> ApiException 으로 변환해 위 레이어로 던진다.
//
// BE 의 글로벌 context-path 가 /api 이므로, 컨트롤러 매핑 /v1/... 의
// 실제 호출 경로는 /api/v1/... 가 된다 (다른 datasource 와 동일 규칙).
class RankingRemoteDataSource {
  final Dio _dio;

  RankingRemoteDataSource(this._dio);

  // GET /api/v1/challenge/participated — 내가 참여한 챌린지 목록 조회
  //
  // 응답 envelope.result 는 ParticipatedChallengeGroupDTO 배열.
  // 참여한 챌린지가 없으면 빈 배열로 도착.
  Future<List<ParticipatedChallengeGroup>> fetchParticipatedGroups() async {
    try {
      final response = await _dio.get('/api/v1/challenge/participated');

      // envelope 에서 result 배열만 꺼내 도메인 리스트로 변환.
      // 빈 배열이면 그대로 빈 리스트가 만들어진다.
      final result = response.data['result'] as List<dynamic>;
      return result
          .map((e) => ParticipatedChallengeGroup.fromJson(
              e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // GET /api/v1/challenge/{challengeId}/ranking — 한 챌린지(한 난이도) 의 랭킹 조회
  //
  // 응답 envelope.result 는 ChallengeRankingResponse 한 객체.
  // 본인 미참가 시에도 200 응답이 오며, myRank / myRunDistance 등이 null 인 채로 도착한다.
  Future<ChallengeRanking> fetchChallengeRanking(int challengeId) async {
    try {
      final response = await _dio.get('/api/v1/challenge/$challengeId/ranking');

      // envelope 에서 result 객체만 꺼내 ChallengeRanking 으로 변환.
      final result = response.data['result'] as Map<String, dynamic>;
      return ChallengeRanking.fromJson(result);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // GET /api/v1/challenge/{challengeId}/me — 본인의 챌린지 상세 조회.
  // 미참가 시 BE 가 404 RECORD_NOT_FOUND 를 던지므로 ApiException 으로 받게 된다.
  Future<MyChallengeDetail> fetchMyChallengeDetail(int challengeId) async {
    try {
      final response = await _dio.get('/api/v1/challenge/$challengeId/me');

      final result = response.data['result'] as Map<String, dynamic>;
      return MyChallengeDetail.fromJson(result);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

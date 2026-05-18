import 'package:dio/dio.dart';

import 'package:running/features/challenge/domain/challenge_list.dart';
import 'package:running/shared/network/api_exception.dart';

// 챌린지 관련 HTTP 요청 전담 클래스.
//
// 책임:
//  - 정해진 엔드포인트로 dio 요청을 던진다.
//  - 응답 envelope( { isSuccess, result, ... } ) 을 풀어 result 안의 데이터를 도메인 객체로 변환.
//  - DioException -> ApiException 으로 변환해 위 레이어로 던진다.
//
// BE 의 글로벌 context-path 가 /api 이므로, 컨트롤러 매핑 /v1/... 의
// 실제 호출 경로는 /api/v1/... 가 된다 (다른 datasource 도 동일 규칙).
class ChallengeRemoteDataSource {
  final Dio _dio;

  ChallengeRemoteDataSource(this._dio);

  // GET /api/v1/challenge — Easy/Hard 챌린지 목록 조회
  //
  // 응답 envelope.result 는 { easy: {...}, hard: {...} } 형태.
  // 각 항목은 ChallengeSummary.fromJson 이 해석할 수 있는 스키마.
  Future<ChallengeList> fetchChallengeList() async {
    try {
      final response = await _dio.get('/api/v1/challenge');

      // envelope 에서 result 만 꺼내 ChallengeList 로 변환
      final result = response.data['result'] as Map<String, dynamic>;
      return ChallengeList.fromJson(result);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

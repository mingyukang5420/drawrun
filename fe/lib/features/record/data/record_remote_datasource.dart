import 'package:dio/dio.dart';

import 'package:running/features/record/data/record_summary_page.dart';
import 'package:running/features/record/domain/record_detail.dart';
import 'package:running/features/record/domain/record_stats.dart';
import 'package:running/shared/network/api_exception.dart';

// 기록 관련 HTTP 요청 전담 클래스
//
// 책임:
//  - 정해진 엔드포인트로 dio 요청을 던진다.
//  - 응답의 envelope( { isSuccess, result, ... } ) 을 풀고
//    result 안쪽 JSON 을 도메인 모델로 변환한다.
//  - DioException → ApiException 변환.
//
// BE 의 글로벌 context-path 가 /api 이므로, 컨트롤러 매핑 /v1/record 의
// 실제 호출 경로는 /api/v1/record 가 된다.
class RecordRemoteDataSource {
  final Dio _dio;

  RecordRemoteDataSource(this._dio);

  // GET /api/v1/record?page=&size= — 히스토리 페이지네이션 조회
  //
  // page 는 0부터 시작. size 기본값은 BE 와 맞춰 10.
  // 응답 envelope 안의 result 는 슬라이스 객체 형태이므로
  // RecordSummaryPage.fromJson 에 위임한다.
  Future<RecordSummaryPage> fetchSummaries({
    required int page,
    int size = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/record',
        queryParameters: {'page': page, 'size': size},
      );
      // response.data 는 envelope 전체. 실제 슬라이스 데이터는 result 키 안.
      final result = response.data['result'] as Map<String, dynamic>;
      return RecordSummaryPage.fromJson(result);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // GET /api/v1/record/{recordId} — 특정 기록 상세 조회
  Future<RecordDetail> fetchDetail(int recordId) async {
    try {
      final response = await _dio.get('/api/v1/record/$recordId');
      final result = response.data['result'] as Map<String, dynamic>;
      return RecordDetail.fromJson(result);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // GET /api/v1/record/stats?period=... — 통계 조회
  //
  // period 는 RecordStatsPeriod.apiValue (week/month/year/all) 중 하나.
  // BE 기본값은 all 이지만 우리는 항상 명시적으로 보낸다.
  Future<RecordStats> fetchStats(String period) async {
    try {
      final response = await _dio.get(
        '/api/v1/record/stats',
        queryParameters: {'period': period},
      );
      final result = response.data['result'] as Map<String, dynamic>;
      return RecordStats.fromJson(result);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // PATCH /api/v1/record/{recordId} — 기록 제목 수정
  //
  // BE 응답 result 는 Void(=null) 이므로 별도 반환값이 없다.
  // 호출 성공 = 200 OK 받았다는 의미. 실패 시 DioException → ApiException 로 던진다.
  Future<void> patchTitle(int recordId, String title) async {
    try {
      await _dio.patch(
        '/api/v1/record/$recordId',
        data: {'title': title},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
import 'package:dio/dio.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/bookmark/domain/bookmark_repository.dart';
import 'package:running/shared/network/api_exception.dart';

// 북마크 관련 HTTP 요청 전담 클래스.
//
// 책임:
//  - 정해진 엔드포인트로 dio 요청을 던진다.
//  - 응답 envelope( { isSuccess, result, ... } ) 을 풀어 result 안의 데이터를 도메인 객체로 변환.
//  - DioException -> ApiException 으로 변환해 위 레이어로 던진다.
class BookmarkRemoteDataSource {
  final Dio _dio;

  BookmarkRemoteDataSource(this._dio);

  // POST /api/v1/course/{courseId}/bookmark — 북마크 추가
  //
  // 성공 응답의 result 는 null 이므로 별도 반환값이 없다.
  // 이미 북마크된 코스에 호출하면 BE 가 400 으로 떨어뜨려 ApiException 이 던져진다.
  Future<void> addBookmark(int courseId) async {
    try {
      await _dio.post('/api/v1/course/$courseId/bookmark');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // DELETE /api/v1/course/{courseId}/bookmark — 북마크 해제
  //
  // 북마크가 없는 코스에 호출해도 400. UI 에서 "현재 북마크됨" 상태일 때만 호출하도록 막아야 한다.
  Future<void> removeBookmark(int courseId) async {
    try {
      await _dio.delete('/api/v1/course/$courseId/bookmark');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // GET /api/v1/member/bookmark/course?page=&size= — 내 북마크 코스 목록
  //
  // 응답 envelope.result 는 { content: [...], page, size, hasNext } 형태이고
  // content 의 각 원소는 코스 목록 카드용 스키마(Course 모델과 동일).
  Future<BookmarkPage> fetchMyBookmarks({
    required int page,
    required int size,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/member/bookmark/course',
        queryParameters: {'page': page, 'size': size},
      );

      // envelope 에서 result 를 꺼내 슬라이스 객체 형태로 다룬다.
      final result = response.data['result'] as Map<String, dynamic>;

      // content 안에는 코스 카드 하나가 한 원소. Course.fromJson 이 이미 그 스키마를 처리한다.
      final content = (result['content'] as List<dynamic>)
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList();

      return BookmarkPage(
        courses: content,
        page: result['page'] as int,
        size: result['size'] as int,
        hasNext: result['hasNext'] as bool,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
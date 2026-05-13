import 'package:dio/dio.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/domain/way.dart';
// CourseStatus 는 course.dart 에서 export 됨
import 'package:running/shared/network/api_exception.dart';

// 코스 관련 HTTP 요청 전담 클래스
// JSON 파싱과 DioException → ApiException 변환을 여기서 처리
class CourseRemoteDataSource {
  final Dio _dio;

  CourseRemoteDataSource(this._dio);

  // GET /api/v1/course — 코스 목록 조회
  // 응답 구조: { "result": { "content": [ ...Course 배열... ] } }
  Future<List<Course>> fetchCourses() async {
    try {
      final response = await _dio.get('/api/v1/course');
      final content =
          response.data['result']['content'] as List<dynamic>;
      return content
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // POST /api/v1/editor — 새 코스 저장
  // trackImageUrl: 지도 스냅샷 업로드 후 받은 공개 URL (있으면 요청 바디에 포함)
  Future<void> createCourse(Course course, {String? trackImageUrl}) async {
    try {
      final data = course.toJson();
      if (trackImageUrl != null && trackImageUrl.isNotEmpty) {
        data['trackImageUrl'] = trackImageUrl;
      }
      await _dio.post('/api/v1/editor', data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // DELETE /api/v1/editor/{editorId} — 코스 삭제
  Future<void> deleteCourse(int editorId) async {
    try {
      await _dio.delete('/api/v1/editor/$editorId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // GET /api/v1/editor?filter={ALL|READY|DONE|REGISTERED}&page= — 내 코스 목록 조회
  // 응답 구조: { "result": { "content": [ ...CourseDraft 배열... ], "page", "size", "hasNext" } }
  Future<List<CourseDraft>> fetchMyCourses(CourseStatus status,
      {int page = 0}) async {
    try {
      final response = await _dio.get(
        '/api/v1/editor',
        queryParameters: {
          'filter': status.queryValue,
          'page': page,
        },
      );
      final content = response.data['result']['content'] as List<dynamic>;
      return content
          .map((e) => CourseDraft.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // GET /api/v1/editor/way — 지도 영역 내 주행 가능 도로 목록 조회
  // 바운딩 박스(minLat~maxLat, minLng~maxLng)와 zoom 을 쿼리 파라미터로 전달
  Future<List<Way>> fetchWays({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required int zoom,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/editor/way',
        queryParameters: {
          'minLat': minLat,
          'minLng': minLng,
          'maxLat': maxLat,
          'maxLng': maxLng,
          'zoom': zoom,
        },
      );
      final ways = response.data['result']['ways'] as List<dynamic>;
      return ways
          .map((e) => Way.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

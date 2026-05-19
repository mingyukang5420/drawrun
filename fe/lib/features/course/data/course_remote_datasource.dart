import 'package:dio/dio.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/domain/course_draft_detail.dart';
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
  // thumbnailBase64: 경로 스냅샷 base64 문자열 (있을 때만 body 에 포함)
  Future<void> createCourse(Course course, {String? thumbnailBase64}) async {
    try {
      final data = course.toJson();
      if (thumbnailBase64 != null) data['thumbnailBase64'] = thumbnailBase64;
      await _dio.post('/api/v1/editor', data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // GET /api/v1/editor/{courseDraftId} — 에디터 코스 상세 조회
  Future<CourseDraftDetail> fetchEditorDetail(int courseDraftId) async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>('/api/v1/editor/$courseDraftId');
      final result = response.data!['result'] as Map<String, dynamic>;
      return CourseDraftDetail.fromJson(result);
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

  // GET /api/v1/editor/challenge?page= — 챌린지 소속 내 코스 목록 조회
  // 챌린지 ID는 백엔드가 JWT 토큰으로 판단하므로 별도 파라미터 불필요
  // 반환: (코스 목록, 챌린지 제목)
  // challengeTitle 은 content 배열 밖 result 레벨에 위치하므로 별도로 파싱
  Future<(List<CourseDraft>, String?)> fetchChallengeCourses(
      {int page = 0}) async {
    try {
      final response = await _dio.get(
        '/api/v1/editor/challenge',
        queryParameters: {'page': page},
      );
      final result = response.data['result'] as Map<String, dynamic>;
      final content = result['content'] as List<dynamic>;
      final challengeTitle = result['challengeTitle'] as String?;
      final courses = content
          .map((e) => CourseDraft.fromJson(e as Map<String, dynamic>))
          .toList();
      return (courses, challengeTitle);
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

import 'package:dio/dio.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/way.dart';
import 'package:running/shared/network/api_exception.dart';

// 코스 관련 HTTP 요청 전담 클래스
// JSON 파싱과 DioException → ApiException 변환을 여기서 처리
// Repository 는 이 클래스를 통해서만 서버와 통신
class CourseRemoteDatasource {
  final Dio _dio;

  CourseRemoteDatasource(this._dio);

  // GET /courses — 전체 코스 목록 조회
  Future<List<Course>> fetchCourses() async {
    try {
      final response = await _dio.get('/courses');
      return (response.data as List<dynamic>)
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // POST /courses — 새 코스 저장
  Future<Course> createCourse(Course course) async {
    try {
      final response = await _dio.post('/courses', data: course.toJson());
      return Course.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // DELETE /courses/{id} — 코스 삭제
  Future<void> deleteCourse(int id) async {
    try {
      await _dio.delete('/courses/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // GET /v1/editor/way — 지도 영역 내 주행 가능 도로 목록 조회
  // 바운딩 박스(minLat~maxLat, minLng~maxLng)와 zoom 을 쿼리 파라미터로 전달
  // 응답 구조: { "result": { "ways": [...] } }
  Future<List<Way>> fetchWays({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required int zoom,
  }) async {
    try {
      final response = await _dio.get(
        '/v1/editor/way',
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

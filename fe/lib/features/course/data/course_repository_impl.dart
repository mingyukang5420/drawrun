import 'package:running/features/course/data/course_remote_datasource.dart';
import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/features/course/domain/way.dart';

// CourseRepository 인터페이스의 구현체
// 실제 데이터 흐름: ViewModel → CourseRepository(interface) → CourseRepositoryImpl → CourseRemoteDataSource
class CourseRepositoryImpl implements CourseRepository {
  final CourseRemoteDataSource _datasource;

  CourseRepositoryImpl(this._datasource);

  @override
  Future<List<Course>> getCourses() => _datasource.fetchCourses();

  @override
  Future<List<CourseDraft>> getMyCourses(CourseStatus status, {int page = 0}) =>
      _datasource.fetchMyCourses(status, page: page);

  @override
  Future<void> saveCourse(Course course, {String? thumbnailBase64}) =>
      _datasource.createCourse(course, thumbnailBase64: thumbnailBase64);

  @override
  Future<void> deleteCourse(int id) => _datasource.deleteCourse(id);

  @override
  Future<List<Way>> getWays({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required int zoom,
  }) =>
      _datasource.fetchWays(
        minLat: minLat,
        minLng: minLng,
        maxLat: maxLat,
        maxLng: maxLng,
        zoom: zoom,
      );
}

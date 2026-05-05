import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/way.dart';

// 코스 저장소 추상 인터페이스 (계약)
//
// Presentation 계층은 이 인터페이스만 알고,
// 실제 구현(CourseRepositoryImpl)은 Data 계층에서 제공
// → 나중에 로컬 DB 구현체로 교체해도 Presentation 코드 변경 불필요
abstract class CourseRepository {
  // 서버에서 코스 전체 목록 조회
  Future<List<Course>> getCourses();

  // 새 코스를 서버에 저장 (응답 바디 불필요)
  Future<void> saveCourse(Course course);

  // id 에 해당하는 코스 삭제
  Future<void> deleteCourse(int id);

  // 지도 영역 내 주행 가능 도로 목록 조회
  // minLat/minLng: 좌하단 좌표, maxLat/maxLng: 우상단 좌표, zoom: 지도 줌 레벨
  Future<List<Way>> getWays({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required int zoom,
  });
}

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/domain/course_draft_detail.dart';
import 'package:running/features/course/domain/way.dart';

// 코스 저장소 추상 인터페이스 (계약)
//
// Presentation 계층은 이 인터페이스만 알고,
// 실제 구현(CourseRepositoryImpl)은 Data 계층에서 제공
// → 나중에 로컬 DB 구현체로 교체해도 Presentation 코드 변경 불필요
abstract class CourseRepository {
  // 서버에서 코스 전체 목록 조회
  Future<List<Course>> getCourses();

  // GET /api/v1/editor?filter=&page= — 내 코스 목록 조회 (status 로 필터)
  Future<List<CourseDraft>> getMyCourses(CourseStatus status, {int page = 0});

  // GET /api/v1/editor/challenge?page= — 챌린지 소속 내 코스 목록 조회
  // 반환: (코스 목록, 챌린지 제목) — challengeTitle 은 result 레벨에서 파싱
  Future<(List<CourseDraft>, String?)> getChallengeCourses({int page = 0});

  // 새 코스를 서버에 저장. 성공 시 BE 가 발급한 courseDraftId 를 반환.
  // 호출 측이 이 ID 로 RunningNotifier.setSessionContext(courseDraftId: ...) 를 부르면
  // 카운트다운에서 시작 API 가 그 draft 의 노드를 받아 지도에 그릴 수 있다.
  // thumbnailBase64: 경로 스냅샷 base64 인코딩 문자열 (신규 에디터에서는 필수)
  Future<int> saveCourse(Course course, {String? thumbnailBase64});

  // GET /api/v1/editor/{courseDraftId} — 에디터 코스 상세 조회
  Future<CourseDraftDetail> getEditorDetail(int courseDraftId);

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

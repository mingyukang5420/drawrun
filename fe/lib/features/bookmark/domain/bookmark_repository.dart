import 'package:running/features/course/domain/course.dart';

// 북마크 도메인의 Repository 계약.
//
// Presentation 계층(ViewModel/Notifier) 은 이 인터페이스만 참조하고,
// 실제 구현체(BookmarkRepositoryImpl) 는 data 레이어에서 주입받는다.
// dio 같은 외부 라이브러리 타입이 여기에 등장하면 안 된다.
abstract class BookmarkRepository {
  // 코스 하나를 내 북마크에 추가한다.
  // 이미 북마크되어 있으면 BE 가 400 으로 응답하므로 ApiException 이 떠오른다.
  Future<void> addBookmark(int courseId);

  // 코스 하나를 내 북마크에서 해제한다.
  // 북마크가 없는 코스에 대해 호출하면 BE 가 400 으로 응답한다.
  Future<void> removeBookmark(int courseId);

  // 내 북마크 코스 목록을 페이지 단위로 받아온다.
  // page 는 0부터 시작, size 는 BE 기본값(10) 과 맞추되 호출자가 덮어쓸 수 있다.
  // 반환되는 Course 객체에는 thumbnail/distance/difficulty 등 목록 카드에 필요한 필드가 들어 있다.
  Future<BookmarkPage> getMyBookmarks({
    int page = 0,
    int size = 10,
  });
}

// 북마크 목록 응답을 슬라이스 형태 그대로 표현하는 값 객체.
//
// BE 는 무한스크롤용으로 hasNext 만 내려주고 전체 개수는 주지 않는다.
// FE 에서도 page/size/hasNext 만 들고 있으면 다음 페이지를 부를 수 있다.
class BookmarkPage {
  // 이번 페이지에 포함된 코스들 (북마크된 코스의 목록 카드용 정보).
  final List<Course> courses;

  // 현재 페이지 번호 (0부터).
  final int page;

  // 현재 페이지 크기.
  final int size;

  // 다음 페이지가 더 있는지 여부.
  final bool hasNext;

  const BookmarkPage({
    required this.courses,
    required this.page,
    required this.size,
    required this.hasNext,
  });
}
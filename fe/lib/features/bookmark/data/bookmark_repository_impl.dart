import 'package:running/features/bookmark/data/bookmark_remote_datasource.dart';
import 'package:running/features/bookmark/domain/bookmark_repository.dart';

// BookmarkRepository 인터페이스의 구체 구현.
//
// 지금은 remote datasource 한 개만 의존하므로 메서드들이 거의 1:1 위임 형태다.
// (로컬 캐시가 생긴다면 이 클래스 안에서 remote/local 조합이 추가된다.)
class BookmarkRepositoryImpl implements BookmarkRepository {
  final BookmarkRemoteDataSource _remote;

  BookmarkRepositoryImpl(this._remote);

  @override
  Future<void> addBookmark(int courseId) => _remote.addBookmark(courseId);

  @override
  Future<void> removeBookmark(int courseId) => _remote.removeBookmark(courseId);

  @override
  Future<BookmarkPage> getMyBookmarks({int page = 0, int size = 10}) =>
      _remote.fetchMyBookmarks(page: page, size: size);
}
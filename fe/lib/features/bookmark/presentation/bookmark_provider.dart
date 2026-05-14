import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/bookmark/data/bookmark_remote_datasource.dart';
import 'package:running/features/bookmark/data/bookmark_repository_impl.dart';
import 'package:running/features/bookmark/domain/bookmark_repository.dart';
import 'package:running/features/bookmark/presentation/bookmarked_course_ids_notifier.dart';
import 'package:running/shared/network/dio_client.dart';
import 'package:running/shared/network/dio_provider.dart';

// 북마크 데이터소스 Provider.
// 앱 전역 dioProvider 를 주입받으므로 인증 인터셉터가 자동으로 적용된다.
final bookmarkRemoteDataSourceProvider = Provider<BookmarkRemoteDataSource>(
      (ref) => BookmarkRemoteDataSource(ref.watch(dioProvider)),
);

// 화면 코드에서 참조할 단 하나의 진입점.
// 인터페이스 타입(BookmarkRepository) 으로 노출해 구현체 교체가 자유롭다.
final bookmarkRepositoryProvider = Provider<BookmarkRepository>(
      (ref) => BookmarkRepositoryImpl(
    ref.watch(bookmarkRemoteDataSourceProvider),
  ),
);

// 북마크된 코스 ID 집합 캐시 Provider.
//
// NotifierProvider 의 팩토리는 ref 를 받지 못하므로 DioClient.create() 로
// Repository 를 직접 조립 — 다른 도메인의 _build* 헬퍼 패턴과 동일.
// autoDispose 를 붙이지 않은 이유: 코스 탐색 / 러닝 / 북마크 목록 여러 화면이
// 같은 캐시를 공유하므로 메인 탭 전환 시마다 리셋되지 않게 전역 수명을 부여한다.
final bookmarkedCourseIdsProvider = NotifierProvider<
    BookmarkedCourseIdsNotifier, BookmarkedCourseIdsState>(
      () => BookmarkedCourseIdsNotifier(
    BookmarkRepositoryImpl(BookmarkRemoteDataSource(DioClient.create())),
  ),
);
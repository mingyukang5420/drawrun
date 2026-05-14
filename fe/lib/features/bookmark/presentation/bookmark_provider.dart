import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/bookmark/data/bookmark_remote_datasource.dart';
import 'package:running/features/bookmark/data/bookmark_repository_impl.dart';
import 'package:running/features/bookmark/domain/bookmark_repository.dart';
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
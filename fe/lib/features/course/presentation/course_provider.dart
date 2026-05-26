import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/data/course_remote_datasource.dart';
import 'package:running/features/course/data/course_repository_impl.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/features/course/presentation/course_detail_viewmodel.dart';
import 'package:running/features/course/presentation/course_editor_viewmodel.dart';
import 'package:running/features/course/presentation/course_management_viewmodel.dart';
import 'package:running/features/course/presentation/course_viewmodel.dart';
import 'package:running/shared/network/dio_client.dart';
import 'package:running/shared/network/dio_provider.dart';

// HTTP 데이터소스 Provider (dioProvider 를 주입받아 생성)
final courseRemoteDataSourceProvider = Provider<CourseRemoteDataSource>(
  (ref) => CourseRemoteDataSource(ref.watch(dioProvider)),
);

// Repository 구현체 Provider (인터페이스 타입으로 노출)
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepositoryImpl(ref.watch(courseRemoteDataSourceProvider)),
);

// CourseNotifier 생성 시 Repository 를 직접 조립하는 팩토리 함수
// NotifierProvider 의 팩토리는 ref 를 제공하지 않으므로
// courseRepositoryProvider 대신 DioClient.create() 로 DI 체인을 직접 구성한다
CourseNotifier _buildCourseNotifier({bool autoLoad = false}) {
  return CourseNotifier(
    CourseRepositoryImpl(CourseRemoteDataSource(DioClient.create())),
    autoLoad: autoLoad,
  );
}

// 코스 목록 화면용 Provider
// autoLoad: true → build() 직후 loadCourses() 자동 호출
// autoDispose: 탭 전환으로 CourseSearchScreen 이 트리를 떠날 때 자동 해제
final courseViewModelProvider =
    NotifierProvider.autoDispose<CourseNotifier, CourseState>(
  () => _buildCourseNotifier(autoLoad: true),
);

// 구 편집 화면용 Provider (기존 CourseMapView 와의 호환성 유지용)
final courseEditorViewModelProvider =
    NotifierProvider.autoDispose<CourseNotifier, CourseState>(
  () => _buildCourseNotifier(),
);

// 코스 관리 화면용 Provider
final courseManagementProvider = NotifierProvider.autoDispose<
    CourseManagementNotifier, CourseManagementState>(
  () => CourseManagementNotifier(
    CourseRepositoryImpl(CourseRemoteDataSource(DioClient.create())),
  ),
);

// 신 코스 편집 화면 전용 Provider
// CourseEditorNotifier 의 독립 인스턴스로 새 편집 화면 상태를 관리
// autoDispose: 편집 화면을 닫을 때 undo/redo 스택 포함 전체 초기화
final courseEditorProvider =
    NotifierProvider.autoDispose<CourseEditorNotifier, CourseEditorState>(
  () => CourseEditorNotifier(
    CourseRepositoryImpl(CourseRemoteDataSource(DioClient.create())),
  ),
);

// 에디터 코스 상세 조회 Provider
// autoDispose: 상세 화면을 닫으면 자동 해제
// courseDraftId 는 화면 진입 후 notifier.load(id) 로 전달한다
final courseDetailProvider =
    NotifierProvider.autoDispose<CourseDetailNotifier, CourseDetailState>(
  () => CourseDetailNotifier(
    CourseRepositoryImpl(CourseRemoteDataSource(DioClient.create())),
  ),
);

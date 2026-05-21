import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course_draft_detail.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/shared/network/api_exception.dart';

class CourseDetailState {
  final bool isLoading;
  final bool isDeleting;
  final CourseDraftDetail? detail;
  final String? errorMessage;

  const CourseDetailState({
    this.isLoading = true,
    this.isDeleting = false,
    this.detail,
    this.errorMessage,
  });

  CourseDetailState copyWith({
    bool? isLoading,
    bool? isDeleting,
    CourseDraftDetail? detail,
    String? errorMessage,
  }) =>
      CourseDetailState(
        isLoading: isLoading ?? this.isLoading,
        isDeleting: isDeleting ?? this.isDeleting,
        detail: detail ?? this.detail,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class CourseDetailNotifier extends Notifier<CourseDetailState> {
  final CourseRepository _repository;
  int? _currentId;

  CourseDetailNotifier(this._repository);

  @override
  CourseDetailState build() => const CourseDetailState(isLoading: true);

  // 화면 진입 직후 호출 — GET /api/v1/editor/{courseDraftId}
  Future<void> load(int courseDraftId) async {
    _currentId = courseDraftId;
    state = const CourseDetailState(isLoading: true);
    try {
      final detail = await _repository.getEditorDetail(courseDraftId);
      state = CourseDetailState(isLoading: false, detail: detail);
    } on ApiException catch (e) {
      state = CourseDetailState(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = CourseDetailState(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> reload() async {
    final id = _currentId;
    if (id == null) return;
    await load(id);
  }

  // DELETE /api/v1/editor/{id} — 성공 시 true 반환
  Future<bool> delete() async {
    final id = _currentId;
    if (id == null) return false;
    state = state.copyWith(isDeleting: true);
    try {
      await _repository.deleteCourse(id);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isDeleting: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isDeleting: false, errorMessage: '삭제에 실패했습니다');
      return false;
    }
  }
}

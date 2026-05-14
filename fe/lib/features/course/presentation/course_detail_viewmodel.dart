import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course_draft_detail.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/shared/network/api_exception.dart';

class CourseDetailState {
  final bool isLoading;
  final CourseDraftDetail? detail;
  final String? errorMessage;

  const CourseDetailState({
    this.isLoading = true,
    this.detail,
    this.errorMessage,
  });

  CourseDetailState copyWith({
    bool? isLoading,
    CourseDraftDetail? detail,
    String? errorMessage,
  }) =>
      CourseDetailState(
        isLoading: isLoading ?? this.isLoading,
        detail: detail ?? this.detail,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// flutter_riverpod 3.x 의 수동 API 는 FamilyNotifier 를 제공하지 않는다.
// RecordDetailNotifier 와 동일하게 평범한 Notifier<T> 를 쓰고
// courseDraftId 는 load() 메서드 인자로 받는다.
// autoDispose Provider 가 화면 push/pop 때마다 인스턴스를 교체해 주므로
// "id 별 독립 인스턴스" 효과가 자동으로 보장된다.
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
    }
  }

  // 다시 시도 버튼용
  Future<void> reload() async {
    final id = _currentId;
    if (id == null) return;
    await load(id);
  }
}

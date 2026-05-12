import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/domain/record_detail.dart';
import 'package:running/features/record/domain/record_repository.dart';
import 'package:running/shared/network/api_exception.dart';

// 상세 화면 상태.
//
// recordId 마다 다른 데이터를 받아 와야 하므로,
// 이 상태를 들고 있는 Notifier 도 recordId 별로 별도 인스턴스를 만든다.
// (record_provider.dart 에서 .family 로 처리)
class RecordDetailState {
  // BE 응답이 도착하면 채워진다. 도착 전에는 null.
  final RecordDetail? data;

  // 첫 진입 시 true → 화면 가운데 스피너.
  final bool isLoading;

  // 에러 메시지. null 이면 정상.
  final String? errorMessage;

  const RecordDetailState({
    this.data,
    this.isLoading = false,
    this.errorMessage,
  });

  RecordDetailState copyWith({
    RecordDetail? data,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecordDetailState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// 상세 화면 Notifier.
//
// flutter_riverpod 3.3.x 의 수동 API 는 base 클래스로 Notifier<T> 와 AsyncNotifier<T>
// 두 가지만 제공한다. FamilyNotifier / AutoDisposeFamilyNotifier 같은 family 변형은
// 코드 생성(@riverpod annotation) 경로로 옮겨져, extend 가능한 클래스로 존재하지 않는다.
// 그래서 이 프로젝트의 다른 ViewModel(RunningNotifier, CourseNotifier, ...) 처럼
// 평범한 Notifier<T> 만 extend 하고, recordId 는 메서드 인자로 받는 패턴을 쓴다.
//
// "다른 recordId 마다 별개 인스턴스" 라는 family 의 효과는 이 화면이 push 될 때마다
// autoDispose Provider 가 새 Notifier 를 만들어 주므로 자동으로 보장된다.
// (push → 새 인스턴스 → 데이터 로드 → pop → autoDispose 가 정리 → 다음 push 때 또 새 인스턴스)
class RecordDetailNotifier extends Notifier<RecordDetailState> {
  final RecordRepository _repository;

  // 마지막으로 load() 가 호출된 recordId 를 보관.
  // 사용자가 "다시 시도" 버튼을 누를 때 refresh() 가 인자 없이도 같은 id 로
  // 재호출할 수 있게 하기 위함이다.
  int? _currentRecordId;

  RecordDetailNotifier(this._repository);

  @override
  RecordDetailState build() {
    // build() 시점에는 recordId 를 아직 모른다.
    // 화면 진입 직후 initState 에서 load(widget.recordId) 가 호출되며 데이터 로드가 시작된다.
    return const RecordDetailState(isLoading: true);
  }

  // 화면에서 한 번 호출해 상세 데이터를 불러온다.
  // 같은 Notifier 인스턴스에 다른 recordId 로 다시 부르는 일은 일반적으로 없지만
  // (push 마다 새 인스턴스가 만들어지므로) 호출되더라도 그대로 새 데이터로 갱신된다.
  Future<void> load(int recordId) async {
    _currentRecordId = recordId;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final detail = await _repository.getDetail(recordId);
      state = state.copyWith(data: detail, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  // "다시 시도" 버튼이 호출하는 진입점.
  // load() 가 한 번도 안 됐다면(이론상 안 나올 케이스) 무시.
  Future<void> refresh() async {
    final id = _currentRecordId;
    if (id == null) return;
    await load(id);
  }

  // 제목 수정 진입점.
  //
  // 흐름:
  //   1) 새 제목으로 BE PATCH 호출.
  //   2) 성공 시 state.data 의 title 만 즉시 갱신 (다른 필드는 그대로 유지).
  //      - BE 응답이 Void 라 새 데이터를 재조회할 수도 있지만, 받은 응답에 신뢰할 수 있는
  //        새 정보가 없으므로 우리가 보낸 title 을 그대로 쓰는 게 효율적이다.
  //   3) 호출 측이 try/catch 로 ApiException 을 받을 수 있도록 그대로 throw.
  //      → 화면이 다이얼로그 안에서 에러 메시지를 표시할 수 있다.
  Future<void> updateTitle(String newTitle) async {
    final id = _currentRecordId;
    final current = state.data;
    if (id == null || current == null) return;

    await _repository.changeTitle(id, newTitle);

    // 성공 시: 로컬 상태의 title 만 새 값으로 교체.
    // copyWith 가 RecordDetail 에 없으므로 동일 필드를 모두 채워 새 인스턴스를 만든다.
    state = state.copyWith(
      data: RecordDetail(
        recordId: current.recordId,
        trackId: current.trackId,
        courseId: current.courseId,
        courseDraftId: current.courseDraftId,
        title: newTitle,
        date: current.date,
        trackImageUrl: current.trackImageUrl,
        distance: current.distance,
        avgPace: current.avgPace,
        runningTime: current.runningTime,
        calories: current.calories,
        cadence: current.cadence,
        isCompleted: current.isCompleted,
        isSafe: current.isSafe,
        nodes: current.nodes,
      ),
    );
  }
}
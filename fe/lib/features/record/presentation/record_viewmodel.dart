import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/domain/record_repository.dart';
import 'package:running/features/record/domain/running_record.dart';
import 'package:running/shared/network/api_exception.dart';

// 기록 화면이 구독하는 불변 상태 클래스
class RecordState {
  final List<RunningRecord> records;
  final bool isLoading;
  final String? errorMessage;

  const RecordState({
    this.records = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  RecordState copyWith({
    List<RunningRecord>? records,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RecordState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// 기록 기능 Notifier
// repository 는 record_provider.dart 의 팩토리에서 생성자로 주입된다
class RecordNotifier extends Notifier<RecordState> {
  final RecordRepository _repository;

  RecordNotifier(this._repository);

  @override
  RecordState build() {
    // 화면 진입 시 자동 로드
    Future.microtask(loadRecords);
    return const RecordState();
  }

  Future<void> loadRecords() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final records = await _repository.getRecords();
      state = state.copyWith(records: records, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }
}

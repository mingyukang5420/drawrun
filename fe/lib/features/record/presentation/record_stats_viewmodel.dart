import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/domain/record_repository.dart';
import 'package:running/features/record/domain/record_stats.dart';
import 'package:running/shared/network/api_exception.dart';

// 통계 화면 상태.
//
// 한 화면 안에서 사용자가 토글로 period 를 바꿀 때마다 같은 Notifier 가
// 새 데이터를 받아 state 를 갱신한다. (Notifier 를 새로 만드는 게 아님)
class RecordStatsState {
  // 현재 선택된 기간.
  final RecordStatsPeriod period;

  // BE 응답 그대로의 통계 데이터.
  // 첫 진입 시점에는 RecordStats.empty 로 채워 nullable 처리를 피한다.
  final RecordStats data;

  // 호출 진행 중 — 토글을 막거나 차트 자리를 스피너로 대체할 때 사용.
  final bool isLoading;

  // 에러 메시지. null 이면 정상.
  final String? errorMessage;

  const RecordStatsState({
    this.period = RecordStatsPeriod.week,
    this.data = RecordStats.empty,
    this.isLoading = false,
    this.errorMessage,
  });

  RecordStatsState copyWith({
    RecordStatsPeriod? period,
    RecordStats? data,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecordStatsState(
      period: period ?? this.period,
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RecordStatsNotifier extends Notifier<RecordStatsState> {
  final RecordRepository _repository;

  RecordStatsNotifier(this._repository);

  @override
  RecordStatsState build() {
    // 시안 기본 선택이 "주" 이므로 week 으로 시작한다.
    Future.microtask(() => load(RecordStatsPeriod.week));
    return const RecordStatsState(
      period: RecordStatsPeriod.week,
      isLoading: true,
    );
  }

  // 사용자가 토글을 눌렀을 때 호출.
  // 같은 period 를 다시 눌러도 강제로 재조회한다 — pull-to-refresh 대용.
  Future<void> load(RecordStatsPeriod period) async {
    state = state.copyWith(
      period: period,
      isLoading: true,
      clearError: true,
    );
    try {
      final data = await _repository.getStats(period.apiValue);
      // 사용자가 호출 도중에 다른 period 로 갈아탔다면 응답을 버린다.
      // 늦게 도착한 응답이 현재 화면의 데이터를 덮어쓰는 사고 방지.
      if (state.period != period) return;
      state = state.copyWith(data: data, isLoading: false);
    } on ApiException catch (e) {
      if (state.period != period) return;
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }
}
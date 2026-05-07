import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/domain/running_session.dart';
import 'package:running/shared/location/location_service.dart';
import 'package:running/shared/map/lat_lng_naver_ext.dart';
import 'package:running/shared/model/lat_lng.dart';
import 'package:running/shared/network/api_exception.dart';
import 'package:running/features/running/domain/running_repository.dart';

// 러닝 화면이 구독하는 불변 상태 클래스
// state = state.copyWith(...) 로 새 객체를 만들어야 Riverpod 이 UI 를 다시 그린다
class RunningState {
  final bool isRunning;
  final bool isPaused;
  final double distanceKm;
  final List<LatLng> points;

  // Ticker 가 1초마다 갱신하는 경과 시간 (초) → UI 클록 리빌드 트리거
  final int elapsedSeconds;

  // 임시값 (데이터 소스 미연결)
  final int caloriesKcal;
  final double altitudeM;
  final int bpm;

  // 분당 발걸음 수.
  final int cadenceSpm;

  final bool isSaving;
  final ApiException? saveError;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const RunningState({
    this.isRunning = false,
    this.isPaused = false,
    this.distanceKm = 0.0,
    this.points = const [],
    this.elapsedSeconds = 0,
    this.caloriesKcal = 0,
    this.altitudeM = 0.0,
    this.bpm = 0,
    this.cadenceSpm = 0,
    this.isSaving = false,
    this.saveError,
    this.startedAt,
    this.endedAt,
  });

  RunningState copyWith({
    bool? isRunning,
    bool? isPaused,
    double? distanceKm,
    List<LatLng>? points,
    int? elapsedSeconds,
    int? caloriesKcal,
    double? altitudeM,
    int? bpm,
    int? cadenceSpm,
    bool? isSaving,
    ApiException? saveError,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return RunningState(
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      distanceKm: distanceKm ?? this.distanceKm,
      points: points ?? this.points,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      altitudeM: altitudeM ?? this.altitudeM,
      bpm: bpm ?? this.bpm,
      cadenceSpm: cadenceSpm ?? this.cadenceSpm,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError ?? this.saveError,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  // UI 표시용 계산 게터
  String get distanceLabel => '${distanceKm.toStringAsFixed(2)} km';

  String get elapsedLabel {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  String get paceLabel {
    // distance 가 너무 작거나 0 이면 의미 없는 큰 값이 나오므로 안 보여 준다.
    // 50 m 미만은 GPS 노이즈로 본다 (필요시 임계 조정).
    if (distanceKm < 0.05) return "--'--\"/km";

    final paceSec = elapsedSeconds / distanceKm;

    // 비현실적으로 느린 페이스도 가드.
    // 60'00"/km (= 시속 1km) 보다 느리면 사실상 멈춰 있는 것에 가까우므로 마스킹.
    if (paceSec > 60 * 60) return "--'--\"/km";

    final m = paceSec ~/ 60;
    final s = (paceSec % 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"/km";
  }

  String get avgPaceLabel => paceLabel;
  String get caloriesLabel => '$caloriesKcal kcal';
  String get altitudeLabel => '${altitudeM.toStringAsFixed(0)} m';
  String get bpmLabel => '$bpm bpm';
  String get cadenceLabel => '$cadenceSpm spm';
}

// ─────────────────────────────────────────────────────────────────────
// RunningNotifier
//
// [Notifier<State> 패턴 요약]
//   state = state.copyWith(...)  → 구독 위젯 자동 리빌드
//   ref.onDispose(...)           → autoDispose 시 자원 정리 자동 실행
//
// mapController, _routeLine, _stopwatch, _ticker, _locationSub 는
// UI 리빌드가 필요 없는 내부 자원이므로 state 가 아닌 인스턴스 변수로 보관
// ─────────────────────────────────────────────────────────────────────
class RunningNotifier extends Notifier<RunningState> {
  // 지도 제어 객체 (state 외부 보관)
  NaverMapController? mapController;
  NPolylineOverlay? _routeLine;

  // 러닝 Repository 필드 및 생성자 추가
  final RunningRepository _repository;
  RunningNotifier(this._repository);

  // 타이밍 도구
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  // GPS 스트림 구독
  StreamSubscription<LatLng>? _locationSub;

  @override
  RunningState build() {
    // Provider 해제(탭 전환 등) 시 자원 자동 정리
    ref.onDispose(() {
      _locationSub?.cancel();
      _ticker?.cancel();
    });
    return const RunningState();
  }

  // 지도가 준비된 뒤 RunningMapView 에서 호출
  void setMapController(NaverMapController controller) {
    mapController = controller;
    // 이전 controller 에 묶여 있던 routeLine 객체는 새 controller 에선 무효 → null 리셋.
    // 안 지우면 _drawRoute 가 deleteOverlay 를 호출하다 옛 controller 참조로 사고 가능.
    _routeLine = null;
    // 시트가 처음 열릴 때 이미 누적된 points 를 즉시 다시 그려줌.
    // 이 한 줄이 없으면 시트 첫 진입 시 폴리라인이 비어있고, 새 점이 와야만 그려짐.
    if (state.points.length >= 2) {
      _drawRoute(state.points);
    }
  }

  // 지도 위젯이 dispose 될 때 호출.
  // 죽은 controller 에 deleteOverlay/addOverlay 가 호출되어
  // MissingPluginException 이 나는 것을 방지하기 위해 참조를 끊는다.
  // _routeLine 도 함께 null 로 — 다음 setMapController 시 새 controller 에 깨끗이 다시 그린다.
  void clearMapController() {
    mapController = null;
    _routeLine = null;
  }

  void startRunning() {
    if (_locationSub != null) return; // 중복 구독 방지
    _stopwatch.start();
    _startTicker();
    _locationSub = LocationService.getLatLngStream().listen(_onLocation);

    // 첫 좌표 즉시 시도 — last known position 이라도 있으면 점 한 개 즉시 찍힘
    LocationService.getCurrentLatLng().then((p) {
      if (p != null && state.isRunning) _onLocation(p);
    });

    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      startedAt: state.startedAt ?? DateTime.now(),
    );
  }

  Future<void> pause() async {
    await _locationSub?.cancel();
    _locationSub = null;
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(isPaused: true);
  }

  void resume() {
    if (_locationSub != null) return;
    _stopwatch.start();
    _startTicker();
    _locationSub = LocationService.getLatLngStream().listen(_onLocation);
    state = state.copyWith(isPaused: false);
  }

  Future<void> finish() async {
    await _locationSub?.cancel();
    _locationSub = null;
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(
      isRunning: false,
      isPaused: false,
      endedAt: DateTime.now(),
    );
  }

  Future<void> clear() async {
    await _locationSub?.cancel();
    _locationSub = null;
    if (mapController != null && _routeLine != null) {
      mapController!.deleteOverlay(_routeLine!.info);
      _routeLine = null;
    }
    _stopwatch.reset();
    _ticker?.cancel();
    _ticker = null;
    state = const RunningState(); // 전체 초기화
  }

  // GPS 좌표 수신 콜백 (스트림 리스너 전용)
  void _onLocation(LatLng point) {
    if (!state.isRunning) return;
    double addedKm = 0;
    if (state.points.isNotEmpty) {
      addedKm = _haversineKm(state.points.last, point);
    }
    final newPoints = [...state.points, point];
    state = state.copyWith(
      points: newPoints,
      distanceKm: state.distanceKm + addedKm,
    );
    _drawRoute(newPoints);
  }

  void _drawRoute(List<LatLng> points) {
    if (mapController == null || points.length < 2) return;
    try {
      if (_routeLine != null) {
        mapController!.deleteOverlay(_routeLine!.info);
      }
      _routeLine = NPolylineOverlay(
        id: 'running_route',
        coords: points.map((p) => p.toNLatLng()).toList(),
        width: 6,
        color: Colors.blueAccent,
      );
      mapController!.addOverlay(_routeLine!);
    } catch (_) {
      // PlatformView 가 dispose 된 직후라면 호출이 실패할 수 있다.
      // 다음 setMapController 호출 시 깨끗이 다시 그릴 수 있도록 참조만 끊고 swallow.
      mapController = null;
      _routeLine = null;
    }
  }

  // 1초마다 elapsedSeconds 갱신 → UI 클록 리빌드
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: _stopwatch.elapsed.inSeconds);
    });
  }

  // 두 GPS 좌표 사이의 구면 거리 (Haversine 공식, km)
  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.latitude)) *
            cos(_toRad(b.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * asin(sqrt(h));
  }

  double _toRad(double deg) => deg * pi / 180;

  // finish() 이후 결과 화면/저장에서 사용
  RunningSession buildSession() {
    final s = state;
    return RunningSession(
      startedAt: s.startedAt ?? DateTime.now(),
      endedAt: s.endedAt ?? DateTime.now(),
      elapsed: Duration(seconds: s.elapsedSeconds),
      distanceKm: s.distanceKm,
      avgPaceSecPerKm:
          s.distanceKm == 0 ? 0.0 : s.elapsedSeconds / s.distanceKm,
      points: List.unmodifiable(s.points),
      caloriesKcal: s.caloriesKcal,
      altitudeM: s.altitudeM,
      bpm: s.bpm,
      cadenceSpm: s.cadenceSpm,
    );
  }

  // 결과 화면 진입 시 한 번 호출. 실패해도 화면은 그대로 보이고
  // saveError 가 채워져 UI 에서 재시도 버튼을 띄울 수 있다.
  Future<void> saveCurrentSession({
    required String title,
    int? courseId,
  }) async {
    state = state.copyWith(isSaving: true, saveError: null);
    try {
      await _repository.save(
        session: buildSession(),
        title: title,
        courseId: courseId,
      );
      state = state.copyWith(isSaving: false);
    } on ApiException catch (e) {
      state = state.copyWith(isSaving: false, saveError: e);
      rethrow;  // 호출부에서 추가 UI 처리 가능하게 다시 던짐
    }
  }
}

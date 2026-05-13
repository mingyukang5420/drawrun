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
import 'package:running/features/running/domain/run_start_response.dart';
import 'package:running/features/running/domain/running_repository.dart';
import 'package:running/shared/sensor/cadence_service.dart';
import 'package:running/shared/sensor/altitude_service.dart';
import 'package:running/shared/calculator/calories_calculator.dart';

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
  final double altitudeM;
  final int bpm;

  // 분당 발걸음 수.
  final int cadenceSpm;

  final bool isSaving;
  final ApiException? saveError;
  final DateTime? startedAt;
  final DateTime? endedAt;

  // 코스/드래프트 진입 시 외부에서 채워 두는 ID 들. 자유 러닝이면 둘 다 null.
  // 시작 API 는 쿼리 파라미터로, 종료 API 는 요청 본문으로 같이 보낸다.
  final int? courseId;
  final int? courseDraftId;

  // 시작 API 응답으로 받은 참조 경로(코스/드래프트의 GPS 노드).
  // 자유 러닝 / 응답 실패 시엔 빈 리스트.
  // 추후 진행 화면 지도에 회색 점선으로 그려 사용자가 따라갈 길잡이로 활용.
  final List<LatLng> referenceNodes;

  const RunningState({
    this.isRunning = false,
    this.isPaused = false,
    this.distanceKm = 0.0,
    this.points = const [],
    this.elapsedSeconds = 0,
    this.altitudeM = 0.0,
    this.bpm = 0,
    this.cadenceSpm = 0,
    this.isSaving = false,
    this.saveError,
    this.startedAt,
    this.endedAt,
    this.courseId,
    this.courseDraftId,
    this.referenceNodes = const [],
  });

  RunningState copyWith({
    bool? isRunning,
    bool? isPaused,
    double? distanceKm,
    List<LatLng>? points,
    int? elapsedSeconds,
    double? altitudeM,
    int? bpm,
    int? cadenceSpm,
    bool? isSaving,
    ApiException? saveError,
    DateTime? startedAt,
    DateTime? endedAt,
    int? courseId,
    int? courseDraftId,
    List<LatLng>? referenceNodes,
  }) {
    return RunningState(
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      distanceKm: distanceKm ?? this.distanceKm,
      points: points ?? this.points,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      altitudeM: altitudeM ?? this.altitudeM,
      bpm: bpm ?? this.bpm,
      cadenceSpm: cadenceSpm ?? this.cadenceSpm,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError ?? this.saveError,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      courseId: courseId ?? this.courseId,
      courseDraftId: courseDraftId ?? this.courseDraftId,
      referenceNodes: referenceNodes ?? this.referenceNodes,
    );
  }

  // UI 표시용 계산 게터
  String get distanceLabel => '${distanceKm.toStringAsFixed(2)}';

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
    if (distanceKm < 0.05) return "--'--\"";

    final paceSec = elapsedSeconds / distanceKm;

    // 비현실적으로 느린 페이스도 가드.
    // 60'00"/km (= 시속 1km) 보다 느리면 사실상 멈춰 있는 것에 가까우므로 마스킹.
    if (paceSec > 60 * 60) return "--'--\"";

    final m = paceSec ~/ 60;
    final s = (paceSec % 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  String get avgPaceLabel => paceLabel;

  // 누적 칼로리 — distance / elapsedSeconds 의 함수.
  // 매 호출마다 다시 계산되지만 곱셈 몇 번이라 비용 무시 가능.
  // TODO: 사용자 성별 도입 후 gender 매개변수 함께 전달.
  int get caloriesKcal => CaloriesCalculator.compute(
    distanceKm: distanceKm,
    elapsedSeconds: elapsedSeconds,
  );

  String get caloriesLabel => '$caloriesKcal';
  String get altitudeLabel => '${altitudeM.toStringAsFixed(0)} m';
  String get bpmLabel => '$bpm';
  String get cadenceLabel => cadenceSpm < 90 ? '--' : '$cadenceSpm';
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
  // 참조 경로(코스/드래프트 노드) 전용 오버레이. 사용자 경로와 별도 운영.
  // _routeLine 과 같은 라이프사이클 정책 — controller 교체 시 null 리셋.
  NPolylineOverlay? _referenceLine;

  // 러닝 Repository 필드 및 생성자 추가
  final RunningRepository _repository;
  RunningNotifier(this._repository);

  // 타이밍 도구
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  // GPS 스트림 구독
  StreamSubscription<LatLng>? _locationSub;

  // CadenceService 의 spmStream 구독 핸들
  final CadenceService _cadence = CadenceService();
  StreamSubscription<int>? _cadenceSub;

  // 고도 측정 서비스. CadenceService와 같은 패턴
  // pause/resume/finish/clear 각 라이프사이클 지점에서 같이 토글
  final AltitudeService _altitude = AltitudeService();
  StreamSubscription<double>? _altitudeSub;

  @override
  RunningState build() {
    // Provider 해제(탭 전환 등) 시 자원 자동 정리
    ref.onDispose(() {
      _locationSub?.cancel();
      _ticker?.cancel();
      _cadenceSub?.cancel();
      _cadence.dispose();
      _altitudeSub?.cancel();
      _altitude.dispose();
    });
    return const RunningState();
  }

  // 지도가 준비된 뒤 RunningMapView 에서 호출
  void setMapController(NaverMapController controller) {
    mapController = controller;
    // 이전 controller 에 묶여 있던 routeLine 객체는 새 controller 에선 무효 → null 리셋.
    // 안 지우면 _drawRoute 가 deleteOverlay 를 호출하다 옛 controller 참조로 사고 가능.
    _routeLine = null;
    _referenceLine = null;
    // 시트가 처음 열릴 때 이미 누적된 points 를 즉시 다시 그려줌.
    // 이 한 줄이 없으면 시트 첫 진입 시 폴리라인이 비어있고, 새 점이 와야만 그려짐.
    if (state.points.length >= 2) {
      _drawRoute(state.points);
    }
    // 시작 API 응답이 이미 도착한 상태였다면 참조 경로도 같은 타이밍에 한 번 그려준다.
    if (state.referenceNodes.length >= 2) {
      _drawReferenceRoute(state.referenceNodes);
    }
  }

  // 지도 위젯이 dispose 될 때 호출.
  // 죽은 controller 에 deleteOverlay/addOverlay 가 호출되어
  // MissingPluginException 이 나는 것을 방지하기 위해 참조를 끊는다.
  // _routeLine 도 함께 null 로 — 다음 setMapController 시 새 controller 에 깨끗이 다시 그린다.
  void clearMapController() {
    mapController = null;
    _routeLine = null;
    _referenceLine = null;
  }

  void startRunning() {
    if (_locationSub != null) return; // 중복 구독 방지
    _stopwatch.start();
    _startTicker();
    _cadence.startListening();
    _cadenceSub = _cadence.spmStream.listen(_onCadence);
    // 고도 측정 시작. 첫 5초간 baseline 워밍업 후 상대 고도가 흐른다.
    _altitude.startListening();
    _altitudeSub = _altitude.altitudeStream.listen(_onAltitude);
    _locationSub = LocationService.getLatLngStream().listen(_onLocation);

    // 첫 좌표 즉시 시도 — last known position 이라도 있으면 점 한 개 즉시 찍힘
    LocationService.getCurrentLatLng().then((p) {
      if (!ref.mounted) return;
      if (p != null && state.isRunning) _onLocation(p);
    });

    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      startedAt: state.startedAt ?? DateTime.now(),
    );
  }

  void syncFromBackground() {
    // 일시정지 / 종료 상태에서는 동기화할 게 없다 (Stopwatch 도 멈춰 있음).
    if (!state.isRunning || state.isPaused) return;
    // _stopwatch 의 진짜 경과 시간으로 상태를 즉시 갱신.
    state = state.copyWith(elapsedSeconds: _stopwatch.elapsed.inSeconds);
    // 멈춰 있던 1초 ticker 도 다시 시동 — 다음 tick 부터 정상.
    _startTicker();
  }

  Future<void> pause() async {
    await _locationSub?.cancel();
    await _cadenceSub?.cancel();
    _locationSub = null;
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    _cadenceSub = null;

    await _cadence.stopListening();

    // 일시정지 시엔 고도 측정도 같이 멈춘다 — 멈춰 있는 동안 기압이 천천히 변동하는
    // 것까지 지표에 반영할 이유가 없다. baseline 은 AltitudeService 가 유지하므로
    // resume 시 같은 baseline 으로 자연스럽게 이어진다.
    await _altitudeSub?.cancel();
    _altitudeSub = null;
    await _altitude.stopListening();
    if (!ref.mounted) return;
    state = state.copyWith(isPaused: true);
  }

  void resume() {
    if (_locationSub != null) return;
    _stopwatch.start();
    _cadence.startListening();
    _startTicker();
    _locationSub = LocationService.getLatLngStream().listen(_onLocation);

    _cadenceSub = _cadence.spmStream.listen(_onCadence);

    // 재개 시 고도도 다시 켠다. baseline 은 유지된 상태 → 출발지 기준 그대로 이어짐.
    _altitude.startListening();
    _altitudeSub = _altitude.altitudeStream.listen(_onAltitude);

    state = state.copyWith(isPaused: false);
  }

  Future<void> finish() async {
    await _locationSub?.cancel();
    await _cadenceSub?.cancel();
    _cadenceSub = null;
    _locationSub = null;
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;

    await _cadence.stopListening();

    // 종료 시 고도도 정리. 마지막으로 흘러온 altitudeM 값이 결과 화면에 그대로 표시.
    await _altitudeSub?.cancel();
    _altitudeSub = null;
    await _altitude.stopListening();
    if (!ref.mounted) return;
    state = state.copyWith(
      isRunning: false,
      isPaused: false,
      endedAt: DateTime.now(),
      elapsedSeconds: _stopwatch.elapsed.inSeconds,
    );
  }

  Future<void> clear() async {
    await _locationSub?.cancel();
    await _cadenceSub?.cancel();
    _locationSub = null;
    _cadenceSub = null;
    if (mapController != null && _routeLine != null) {
      mapController!.deleteOverlay(_routeLine!.info);
      _routeLine = null;
    }
    if (mapController != null && _referenceLine != null) {
      mapController!.deleteOverlay(_referenceLine!.info);
      _referenceLine = null;
    }
    _stopwatch.reset();
    _ticker?.cancel();
    _ticker = null;

    await _cadence.stopListening();

    // clear 는 "다시 처음으로" — 고도 측정도 같이 정리.
    // baseline 까지 폐기해야 다음 시작에서 새 출발지 기준으로 재워밍업이 동작한다.
    // stopListening 만으론 baseline 이 남아 다음 세션이 옛 baseline 으로 시작된다.
    await _altitudeSub?.cancel();
    _altitudeSub = null;
    await _altitude.stopListening();
    _altitude.reset();
    if (!ref.mounted) return;
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

  // CadenceService 가 spm 한 값을 흘려줄 때마다 호출.
  // state 의 cadenceSpm 만 갈아끼우면 ref.watch 한 화면이 자동 리빌드된다.
  void _onCadence(int spm) {
    // 일시정지/종료 직후 늦게 도착한 이벤트는 무시 — 표시값이 튀지 않게.
    if (!state.isRunning || state.isPaused) return;
    state = state.copyWith(cadenceSpm: spm);
  }

  // AltitudeService 가 새 고도값을 흘려줄 때마다 호출.
  // state 의 altitudeM 만 갈아끼우면 ref.watch 한 화면이 자동 리빌드된다.
  void _onAltitude(double altitudeM) {
    // 일시정지/종료 직후 늦게 도착한 이벤트는 무시 — 표시값 튐 방지.
    if (!state.isRunning || state.isPaused) return;
    state = state.copyWith(altitudeM: altitudeM);
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

  // 참조 경로(코스/드래프트의 GPS 노드) 를 그레이 폴리라인으로 한 번 그린다.
  // 사용자 경로(_drawRoute) 와 달리 노드가 시간에 따라 늘어나지 않으므로 단발성 호출.
  //
  // 호출 시점:
  //   (a) setMapController — 시트 진입 시 이미 응답이 와 있다면 즉시
  //   (b) beginSessionFromServer — 응답이 늦게 도착했고 컨트롤러가 살아있을 때(R2 에서 추가)
  void _drawReferenceRoute(List<LatLng> nodes) {
    if (mapController == null || nodes.length < 2) return;
    try {
      // 이전 오버레이가 남아 있으면 먼저 제거 — 같은 id 로 두 번 add 하면 충돌.
      if (_referenceLine != null) {
        mapController!.deleteOverlay(_referenceLine!.info);
      }
      _referenceLine = NPolylineOverlay(
        id: 'running_reference',
        coords: nodes.map((p) => p.toNLatLng()).toList(),
        // 사용자 경로(blueAccent, width 6) 보다 한 단계 얇고 무채색 — 본인 경로가 도드라지게.
        width: 4,
        color: const Color(0xFF9CA3AF),
      );
      mapController!.addOverlay(_referenceLine!);
    } catch (_) {
      // _drawRoute 와 동일 정책: PlatformView dispose 직후라면 호출이 실패할 수 있다.
      // 참조만 끊고 swallow — 다음 setMapController 호출 시 깨끗이 다시 그린다.
      _referenceLine = null;
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
    required String trackImageUrl,
    int? courseId,
    int? courseDraftId,
  }) async {
    state = state.copyWith(isSaving: true, saveError: null);
    try {
      await _repository.save(
        session: buildSession(),
        title: title,
        trackImageUrl: trackImageUrl,
        courseId: courseId,
        courseDraftId: courseDraftId,
      );
      state = state.copyWith(isSaving: false);
    } on ApiException catch (e) {
      state = state.copyWith(isSaving: false, saveError: e);
      rethrow;
    }
  }

  // 카운트다운 화면에서 한 번 호출 — 시작 API 발사 후 응답 nodes 를 state 에 보관.
  //
  // fail-open 정책:
  //   네트워크 실패가 나도 예외를 위로 던지지 않는다. referenceNodes 만 빈 채로 둘 뿐
  //   GPS 측정 / 종료 저장은 정상 진행된다. 사용자 입장에선 "참조 경로가 안 보일 뿐".
  //
  // courseId / courseDraftId 는 현재 state 값을 그대로 사용 —
  // 추후 코스/드래프트 진입 화면이 router 단계에서 state.copyWith(courseId: X) 로 박아두면
  // 여기서 자동으로 따라간다.
  Future<void> beginSessionFromServer() async {
    try {
      final response = await _repository.startSession(
        courseId: state.courseId,
        courseDraftId: state.courseDraftId,
      );
      state = state.copyWith(referenceNodes: response.nodes);
      // 시트가 이미 열려 있어 컨트롤러가 살아있는 경우엔 즉시 그려준다.
      // 컨트롤러가 없으면 다음 setMapController(R1) 진입 시점에 자동으로 그려진다.
      if (mapController != null && response.nodes.length >= 2) {
        _drawReferenceRoute(response.nodes);
      }
    } on ApiException catch (e) {
      // 측정은 그대로 진행. 로그만 남겨 운영에서 모니터링 가능하게.
      debugPrint('run/start 실패 (fail-open): ${e.message}');
    }
  }
}

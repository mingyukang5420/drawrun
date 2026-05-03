import 'dart:math';
import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:running/shared/location/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:running/shared/map/lat_lng_naver_ext.dart';
import 'package:running/features/running/domain/running_repository.dart';
import 'package:running/features/running/domain/running_session.dart';
import 'package:running/shared/network/api_exception.dart';

import '../../../shared/model/lat_lng.dart';

// 러닝 도메인의 상태와 로직을 관리하는 컨트롤러
// ChangeNotifier 를 상속하면 notifyListeners() 호출 시 Consumer 위젯이 자동으로 다시 그려진다.
class RunningViewModel extends ChangeNotifier {
  // 현재 러닝 중인지 여부
  bool isRunning = false;

  // 현재 일시정지 여부
  bool isPaused = false;

  // 누적 이동 거리 (km 단위)
  double distanceKm = 0.0;

  // 지도에 찍힌 좌표 목록 (경로를 구성하는 점들)
  final List<LatLng> points = [];

  // 시간 측정
  // pause 시 stop, resume 시 start, finish/clear 시 reset
  final Stopwatch _stopwatch = Stopwatch();

  // 1초마다 notifyListeners()를 호출해서 UI의 elapsedLabel이 갱신되도록 만듬
  // pause/finish/clear/dispose 시 반드시 cancel
  Timer? _ticker;

  // 첫 startRunning() 호출 시 한 번만 기록. resume 에서는 갱신하지 않음
  DateTime? _startedAt;

  // finish() 시점의 시각 결과 화면 헤더와 RunningSession 에 사용.
  DateTime? endedAt;

  // 임시값 아직 칼로리, 고도?경사?, 심박수 관련 로직이 없기 때문
  // 데이터 소스 붙으면 내부에서만 갱신되고 UI/세션은 자동 반영됨.
  int caloriesKcal = 0;
  double altitudeM = 0.0;
  int bpm = 0;

  // 결과 화면이 watch 하여 스피너/에러 UI 를 표시한다.
  bool isSaving = false;
  ApiException? saveError;

  // 지도 위에 그려진 경로 선 오버레이 (null 이면 아직 그려지지 않은 상태)
  NPolylineOverlay? routeLine;

  // 지도를 직접 제어하는 객체. onMapReady 콜백에서 등록된다.
  NaverMapController? mapController;

  // GPS 스트림 구독
  // 시작 전/정지 후엔 null - null 여부로 구독 활성 상태 판별
  StreamSubscription<LatLng>? _locationSub;

  // 지도가 준비된 뒤 RunningMapView 에서 호출한다
  void setMapController(NaverMapController controller) {
    mapController = controller;
  }

  void startRunning() {
    // 이미 GPS 스트림이 구독되어 있는지 판단
    // 중복좌표 예방
    if(_locationSub != null) return;
    isRunning = true;
    isPaused = false;
    _startedAt ??= DateTime.now();
    _stopwatch.start();
    _startTicker();

    // GPS 스트림 구독 시작
    // distanceFilter가 5 이므로 5m 이상 이동했을 경우에 좌표 저장
    _locationSub = LocationService.getLatLngStream().listen(addPoint);
    notifyListeners();
  }

  // 일시정지
  Future<void> pause() async {
    await _locationSub?.cancel();
    _locationSub = null;
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    isPaused = true;
    notifyListeners();
  }

  // 재개
  void resume() {
    // 중복방지
    if (_locationSub != null) return;
    _stopwatch.start();
    _startTicker();
    _locationSub = LocationService.getLatLngStream().listen(addPoint);
    isPaused = false;
    notifyListeners();
  }

  // 종료
  Future<void> finish() async {
    // GPS 스트림 구독 취소
    // cancel()은 Future을 반환하므로 await으로 정리가 끝난 뒤 null로 되돌림
    await _locationSub?.cancel();
    _locationSub = null;
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    endedAt = DateTime.now();
    isRunning = false;
    isPaused = false;
    notifyListeners();
  }

  // 1초마다 콜백을 호출해서 -> watch중인 모든 위젯이 다시 빌드
  void _startTicker() {
    // 중복방지
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  // 새 좌표를 경로에 추가한다. 러닝 중이 아니면 무시한다
  void addPoint(LatLng point) {
    if (!isRunning) return;

    // 이전 점이 있으면 두 점 사이의 거리를 누적한다
    if (points.isNotEmpty) {
      distanceKm += _haversineKm(points.last, point);
    }

    points.add(point);
    _drawRoute();
    notifyListeners();
  }

  // 경로와 상태를 모두 초기화한다
  Future<void> clear() async {
    // GPS 스트림 구독 먼저 취소
    // 해당 로직이 없으면 초기화 버튼을 누르자마자 새 좌표가 들어옴
    await _locationSub?.cancel();
    _locationSub = null;

    // 지도에서 폴리라인 오버레이 제거
    if (mapController != null && routeLine != null) {
      mapController!.deleteOverlay(routeLine!.info);
      routeLine = null;
    }

    // 메모리 상태도 함께 초기화
    points.clear();
    distanceKm = 0.0;
    isRunning = false;
    isPaused = false;
    _stopwatch.reset();
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    endedAt = null;
    saveError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _locationSub = null;
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  // points 목록을 바탕으로 지도에 경로 선을 다시 그린다
  void _drawRoute() {
    // 점이 2개 미만이면 선을 그릴 수 없다
    if (mapController == null || points.length < 2) return;

    // 기존 경로 선을 먼저 지운다 (덮어쓰기 방지)
    if (routeLine != null) {
      mapController!.deleteOverlay(routeLine!.info);
    }

    routeLine = NPolylineOverlay(
      id: 'running_route',
      coords: points.map((p) => p.toNLatLng()).toList(),
      width: 6,
      color: Colors.blueAccent,
    );

    mapController!.addOverlay(routeLine!);
  }

  // 두 GPS 좌표 사이의 거리를 km 단위로 반환한다 (Haversine 공식)
  // 지구 곡률을 고려한 구면 거리 계산 방식으로, GPS 거리 측정에 표준적으로 사용된다.
  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0; // 지구 반지름 (km)
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

  // UI 에서 바로 사용할 수 있는 거리 문자열 (예: "1.23 km")
  String get distanceLabel => '${distanceKm.toStringAsFixed(2)} km';

  // 경과 시간 노출 (UI 가 실시간 표시할 때 사용)
  Duration get elapsed => _stopwatch.elapsed;

  // 시:분:초 두 자리 고정
  String get elapsedLabel {
    final s = _stopwatch.elapsed;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = s.inHours;
    final m = s.inMinutes.remainder(60);
    final sec = s.inSeconds.remainder(60);
    return '${two(h)}:${two(m)}:${two(sec)}';
  }

  // 평균 페이스 = 경과(초) / 거리(km)  →  분'초"/km
  // 거리 0 일 땐 "--'--\"" 로 표시
  String get paceLabel {
    if (distanceKm == 0) return '--\'--"';
    final paceSec = _stopwatch.elapsed.inSeconds / distanceKm;
    final m = paceSec ~/ 60;
    final s = (paceSec % 60).round();
    final ss = s.toString().padLeft(2, '0');
    return "$m'$ss\"/km";
  }

  // 결과 화면도 동일 식
  String get avgPaceLabel => paceLabel;

  // 임시값 라벨
  String get caloriesLabel => '$caloriesKcal kcal';
  String get altitudeLabel => '${altitudeM.toStringAsFixed(0)} m';
  String get bpmLabel => '$bpm bpm';

  // 현 시점 상태로 RunningSession 생성. finish() 이후 결과 화면/저장에서 사용.
  RunningSession buildSession() {
    final paceSec = distanceKm == 0
        ? 0.0
        : _stopwatch.elapsed.inSeconds / distanceKm;

    return RunningSession(
      startedAt: _startedAt ?? DateTime.now(),
      endedAt: endedAt ?? DateTime.now(),
      elapsed: _stopwatch.elapsed,
      distanceKm: distanceKm,
      avgPaceSecPerKm: paceSec,
      points: List.unmodifiable(points),  // 외부에서 변경 못 하게 방어 복사
      caloriesKcal: caloriesKcal,
      altitudeM: altitudeM,
      bpm: bpm,
    );
  }
}

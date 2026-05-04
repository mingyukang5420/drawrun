import 'dart:math';

import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/shared/model/lat_lng.dart' as shared;
import 'package:running/shared/network/api_exception.dart';

// 코스 화면이 구독하는 불변 상태 클래스
// 목록 화면(CourseScreen)과 편집 화면(CourseEditorScreen) 이
// 각각 별도 Provider 인스턴스를 통해 공유한다
class CourseState {
  // ── 목록 상태 ──────────────────────────────────
  final List<Course> courses;
  final bool isLoading;
  final String? errorMessage;

  // ── 편집 상태 ───────────────────────────────────
  // 지도에서 탭한 좌표 목록 (경로 점)
  final List<NLatLng> points;

  const CourseState({
    this.courses = const [],
    this.isLoading = false,
    this.errorMessage,
    this.points = const [],
  });

  CourseState copyWith({
    List<Course>? courses,
    bool? isLoading,
    String? errorMessage,
    List<NLatLng>? points,
  }) {
    return CourseState(
      courses: courses ?? this.courses,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      points: points ?? this.points,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// CourseNotifier
//
// [MVVM 역할 분담]
// View (Screen/Widget) → 상태를 읽고 사용자 이벤트를 Notifier 에 전달
// Notifier (이 클래스) → state 보유, Repository 호출, 지도 편집 로직
// Model (domain/course) → 순수 데이터 구조
//
// repository 는 course_provider.dart 의 팩토리에서 생성자로 주입된다.
// 순환 임포트를 피하기 위해 Notifier 가 직접 Provider 를 참조하지 않는다.
// ─────────────────────────────────────────────────────────────────────
class CourseNotifier extends Notifier<CourseState> {
  final CourseRepository _repository;

  // autoLoad: true 면 build() 직후 loadCourses() 자동 호출 (목록 화면용)
  final bool _autoLoad;

  CourseNotifier(this._repository, {bool autoLoad = false})
      : _autoLoad = autoLoad;

  // 지도 SDK 컨트롤러 (UI 리빌드 없이 지도에 직접 그릴 때 사용)
  NaverMapController? mapController;
  NPolylineOverlay? _routeLine;

  @override
  CourseState build() {
    if (_autoLoad) {
      // build() 가 동기 반환 후 비동기 로드를 시작한다
      Future.microtask(loadCourses);
    }
    return const CourseState();
  }

  // ── 목록 메서드 ────────────────────────────────

  Future<void> loadCourses() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final courses = await _repository.getCourses();
      state = state.copyWith(courses: courses, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  Future<void> saveCourse(String name) async {
    if (state.points.isEmpty) return;

    // 지도용 NLatLng → 도메인용 shared.LatLng 변환
    final domainPoints = state.points
        .map((p) => shared.LatLng(latitude: p.latitude, longitude: p.longitude))
        .toList();

    final course = Course(
      name: name,
      distanceKm: _calculateDistanceKm(),
      points: domainPoints,
    );

    try {
      await _repository.saveCourse(course);
      clear(); // 저장 성공 후 편집 상태 초기화
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    }
  }

  Future<void> deleteCourse(int id) async {
    try {
      await _repository.deleteCourse(id);
      await loadCourses();
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    }
  }

  // ── 편집 메서드 ────────────────────────────────

  void setMapController(NaverMapController controller) {
    mapController = controller;
  }

  void addPoint(NLatLng point) {
    final newPoints = [...state.points, point];
    state = state.copyWith(points: newPoints);
    _drawRoute(newPoints);
  }

  void clear() {
    if (mapController != null && _routeLine != null) {
      mapController!.deleteOverlay(_routeLine!.info);
      _routeLine = null;
    }
    state = state.copyWith(points: []);
  }

  void _drawRoute(List<NLatLng> points) {
    if (mapController == null || points.length < 2) return;
    if (_routeLine != null) {
      mapController!.deleteOverlay(_routeLine!.info);
    }
    _routeLine = NPolylineOverlay(
      id: 'course_route',
      coords: points,
      width: 6,
    );
    mapController!.addOverlay(_routeLine!);
  }

  double _calculateDistanceKm() {
    double total = 0;
    final pts = state.points;
    for (int i = 0; i < pts.length - 1; i++) {
      total += _haversineKm(pts[i], pts[i + 1]);
    }
    return total;
  }

  double _haversineKm(NLatLng a, NLatLng b) {
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
}

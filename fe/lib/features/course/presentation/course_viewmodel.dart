import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/shared/model/lat_lng.dart' as shared;
import 'package:running/shared/network/api_exception.dart';

// 코스 기능의 상태와 비즈니스 로직을 관리하는 ViewModel
//
// [MVVM 역할 분담]
// View  (Screen/Widget) → 상태를 읽고 사용자 이벤트를 ViewModel 에 전달
// ViewModel (이 파일)   → 상태 보유, Repository 호출, 지도 편집 로직 처리
// Model (domain/course) → 순수 데이터 구조
//
// [상태 종류]
// 목록 상태: courses, isLoading, errorMessage  (CourseScreen 에서 사용)
// 편집 상태: points, routeLine, mapController  (CourseEditorScreen 에서 사용)
class CourseViewModel extends ChangeNotifier {
  final CourseRepository _repository;

  CourseViewModel(this._repository);

  // ── 목록 상태 ──────────────────────────────
  // 서버에서 불러온 코스 목록
  List<Course> courses = [];

  // 서버 통신 중 로딩 표시 여부
  bool isLoading = false;

  // API 호출 실패 시 화면에 표시할 메시지 (null 이면 오류 없음)
  String? errorMessage;

  // ── 지도 편집 상태 ─────────────────────────
  // 지도에서 탭한 좌표 목록 (경로를 구성하는 점)
  final List<NLatLng> points = [];

  // 지도에 그려진 경로 오버레이 (null 이면 아직 그려지지 않은 상태)
  NPolylineOverlay? routeLine;

  // 지도 SDK 컨트롤러. onMapReady 콜백에서 등록
  NaverMapController? mapController;

  // ── 목록 메서드 ────────────────────────────

  // 서버에서 코스 전체 목록 로드
  Future<void> loadCourses() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      courses = await _repository.getCourses();
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 현재 편집 중인 경로를 코스로 저장
  Future<void> saveCourse(String name) async {
    if (points.isEmpty) return;

    // 지도용 NLatLng → 도메인용 shared.LatLng 변환
    final domainPoints = points
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
      errorMessage = e.message;
      notifyListeners();
    }
  }

  // 코스 삭제 후 목록 새로고침
  Future<void> deleteCourse(int id) async {
    try {
      await _repository.deleteCourse(id);
      await loadCourses();
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
    }
  }

  // ── 편집 메서드 ────────────────────────────

  // 지도가 준비된 뒤 CourseMapView 에서 호출
  void setMapController(NaverMapController controller) {
    mapController = controller;
  }

  // 지도 탭 시 경로 점 추가
  void addPoint(NLatLng point) {
    points.add(point);
    _drawRoute();
    notifyListeners();
  }

  // 편집 중인 경로와 지도 오버레이 초기화
  void clear() {
    if (mapController != null && routeLine != null) {
      mapController!.deleteOverlay(routeLine!.info);
      routeLine = null;
    }
    points.clear();
    notifyListeners();
  }

  // points 를 이어 지도에 폴리라인 경로 표시
  void _drawRoute() {
    if (mapController == null || points.length < 2) return;
    if (routeLine != null) {
      mapController!.deleteOverlay(routeLine!.info);
    }
    routeLine = NPolylineOverlay(
      id: 'course_route',
      coords: points,
      width: 6,
    );
    mapController!.addOverlay(routeLine!);
  }

  // ── 유틸리티 ───────────────────────────────

  // points 전체 구간 합산 거리 (km 단위) 계산 결과
  double _calculateDistanceKm() {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _haversineKm(points[i], points[i + 1]);
    }
    return total;
  }

  // 두 GPS 좌표 사이의 구면 거리 (Haversine 공식)
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

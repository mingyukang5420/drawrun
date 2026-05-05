import 'dart:math';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/shared/location/location_service.dart';
import 'package:running/shared/model/lat_lng.dart' as shared;
import 'package:running/shared/network/api_exception.dart';

// 경로 폴리라인 색상 상수 (주황-빨강 계열로 지도에서 시각적으로 강조)
const kCourseRouteColor = Color(0xFFFF5722);

// 코스 편집 화면의 불변 상태 클래스
// 모든 필드는 final 로 선언하고 copyWith 로만 갱신한다
class CourseEditorState {
  // 사용자가 입력한 코스 이름 (상단 바에서 수정 가능)
  final String courseName;

  // 지도에서 탭해 추가된 경로 노드(좌표) 목록
  final List<NLatLng> nodes;

  // 실행취소를 위한 이전 노드 목록 스냅샷 스택
  // 각 원소가 addNode 호출 직전의 nodes 복사본
  final List<List<NLatLng>> undoStack;

  // 다시실행을 위한 노드 목록 스냅샷 스택
  // undo 할 때 현재 nodes 가 여기 저장됨
  final List<List<NLatLng>> redoStack;

  // 노드 간 하버사인 거리 합산 결과 (km 단위)
  final double totalDistanceKm;

  // 도로 자동 추종(AutoSnap) 기능 활성화 여부
  final bool autoSnap;

  // 서버 저장 요청 진행 중 여부 (버튼 비활성화·스피너 표시용)
  final bool isSaving;

  // 저장 실패 시 설정되는 오류 메시지
  final String? saveError;

  const CourseEditorState({
    this.courseName = '새 코스',
    this.nodes = const [],
    this.undoStack = const [],
    this.redoStack = const [],
    this.totalDistanceKm = 0.0,
    this.autoSnap = false,
    this.isSaving = false,
    this.saveError,
  });

  CourseEditorState copyWith({
    String? courseName,
    List<NLatLng>? nodes,
    List<List<NLatLng>>? undoStack,
    List<List<NLatLng>>? redoStack,
    double? totalDistanceKm,
    bool? autoSnap,
    bool? isSaving,
    // ?? 대신 직접 할당 → null 로 명시적으로 초기화 가능
    Object? saveError = _sentinel,
  }) {
    return CourseEditorState(
      courseName: courseName ?? this.courseName,
      nodes: nodes ?? this.nodes,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      autoSnap: autoSnap ?? this.autoSnap,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError == _sentinel
          ? this.saveError
          : saveError as String?,
    );
  }
}

// saveError 를 null 로 명시 초기화하기 위한 센티널 상수
const _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────
// CourseEditorNotifier
//
// 코스 편집 화면의 비즈니스 로직을 담당한다
// · 노드 추가·실행취소·다시실행·전체초기화
// · 폴리라인 오버레이 갱신 (지도 SDK 직접 조작)
// · 총 거리 실시간 계산 (하버사인 공식)
// · 서버 저장 요청
//
// repository 는 course_provider.dart 에서 생성자로 주입한다
// ─────────────────────────────────────────────────────────────────────
class CourseEditorNotifier extends Notifier<CourseEditorState> {
  final CourseRepository _repository;

  CourseEditorNotifier(this._repository);

  // 네이버 지도 SDK 컨트롤러 (오버레이 직접 그리기에 사용)
  NaverMapController? _mapController;

  // 현재 지도에 그려진 경로 폴리라인 오버레이
  NPolylineOverlay? _routeLine;

  @override
  CourseEditorState build() => const CourseEditorState();

  // 지도 컨트롤러 등록 (onMapReady 콜백에서 1회 호출)
  void setMapController(NaverMapController controller) {
    _mapController = controller;
  }

  // 코스 이름 변경 (상단 바 편집 다이얼로그에서 호출)
  void setCourseName(String name) {
    state = state.copyWith(courseName: name);
  }

  // 지도 탭 → 새 노드 추가
  // 추가 전 nodes 를 undoStack 에 보관하고 redoStack 은 비운다
  void addNode(NLatLng point) {
    final newUndo = [...state.undoStack, List<NLatLng>.from(state.nodes)];
    final newNodes = [...state.nodes, point];
    state = state.copyWith(
      nodes: newNodes,
      undoStack: newUndo,
      redoStack: [], // 새 동작이 생기면 redo 이력 초기화
      totalDistanceKm: _calcDistance(newNodes),
    );
    _drawRoute(newNodes);
  }

  // 마지막 addNode 를 취소하고 직전 노드 상태로 복원
  void undo() {
    if (state.undoStack.isEmpty) return;
    final prevNodes = state.undoStack.last;
    final newUndo = state.undoStack.sublist(0, state.undoStack.length - 1);
    final newRedo = [...state.redoStack, List<NLatLng>.from(state.nodes)];
    state = state.copyWith(
      nodes: prevNodes,
      undoStack: newUndo,
      redoStack: newRedo,
      totalDistanceKm: _calcDistance(prevNodes),
    );
    _drawRoute(prevNodes);
  }

  // 취소했던 addNode 를 다시 적용
  void redo() {
    if (state.redoStack.isEmpty) return;
    final nextNodes = state.redoStack.last;
    final newRedo = state.redoStack.sublist(0, state.redoStack.length - 1);
    final newUndo = [...state.undoStack, List<NLatLng>.from(state.nodes)];
    state = state.copyWith(
      nodes: nextNodes,
      undoStack: newUndo,
      redoStack: newRedo,
      totalDistanceKm: _calcDistance(nextNodes),
    );
    _drawRoute(nextNodes);
  }

  // 모든 노드·스택 초기화 + 지도 폴리라인 제거
  void reset() {
    _clearPolyline();
    state = state.copyWith(
      nodes: [],
      undoStack: [],
      redoStack: [],
      totalDistanceKm: 0.0,
    );
  }

  // 도로 자동 추종 기능 ON/OFF 토글
  void toggleAutoSnap() {
    state = state.copyWith(autoSnap: !state.autoSnap);
  }

  // 현재 GPS 위치로 카메라 이동
  Future<void> centerOnCurrentLocation() async {
    if (_mapController == null) return;
    final position = await LocationService.getCurrentPosition();
    if (position == null) return;
    await _mapController!.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(position.latitude, position.longitude),
        zoom: 16,
      ),
    );
  }

  // 검색으로 선택한 좌표로 카메라 이동 (바텀 시트에서 호출)
  Future<void> moveCameraTo(NLatLng target) async {
    if (_mapController == null) return;
    await _mapController!.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: target, zoom: 16),
    );
  }

  // 현재 경로를 서버에 저장
  // isSaving 플래그로 저장 진행 상태를 UI 에 전달한다
  Future<void> saveCourse() async {
    if (state.nodes.isEmpty) return;
    state = state.copyWith(isSaving: true, saveError: null);

    // 지도 SDK 타입(NLatLng) → 도메인 타입(shared.LatLng) 변환
    final domainPoints = state.nodes
        .map((p) => shared.LatLng(latitude: p.latitude, longitude: p.longitude))
        .toList();

    final course = Course(
      title: state.courseName,
      distance: state.totalDistanceKm,
      points: domainPoints,
    );

    try {
      await _repository.saveCourse(course);
      state = state.copyWith(isSaving: false);
      reset(); // 저장 성공 후 편집 상태를 초기화
    } on ApiException catch (e) {
      state = state.copyWith(isSaving: false, saveError: e.message);
    } catch (_) {
      // ApiException 이외의 예외 (JSON 파싱 오류 등) 를 일반 메시지로 처리
      state = state.copyWith(isSaving: false, saveError: '저장 중 오류가 발생했습니다');
    }
  }

  // 노드 목록으로 폴리라인을 지도에 다시 그린다
  void _drawRoute(List<NLatLng> nodes) {
    if (_mapController == null) return;
    _clearPolyline();
    if (nodes.length < 2) return;
    _routeLine = NPolylineOverlay(
      id: 'editor_route',
      coords: nodes,
      color: kCourseRouteColor, // 경로 색상 (주황-빨강)
      width: 6,
    );
    _mapController!.addOverlay(_routeLine!);
  }

  // 기존 폴리라인 오버레이를 지도에서 제거
  void _clearPolyline() {
    if (_mapController != null && _routeLine != null) {
      _mapController!.deleteOverlay(_routeLine!.info);
      _routeLine = null;
    }
  }

  // 노드 목록의 총 거리를 하버사인 공식으로 계산 (km)
  double _calcDistance(List<NLatLng> nodes) {
    double total = 0;
    for (int i = 0; i < nodes.length - 1; i++) {
      total += _haversineKm(nodes[i], nodes[i + 1]);
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

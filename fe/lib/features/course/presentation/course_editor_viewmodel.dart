import 'dart:math';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_repository.dart';
import 'package:running/features/course/domain/way.dart';
import 'package:running/shared/location/location_service.dart';
import 'package:running/shared/model/lat_lng.dart' as shared;
import 'package:running/shared/network/api_exception.dart';

// 경로 폴리라인 색상 상수 (주황-빨강 계열로 지도에서 시각적으로 강조)
const kCourseRouteColor = Color(0xFFFF5722);

// Dijkstra 라우팅 그래프의 방향 엣지
// to: 도착 꼭짓점 키(_latlngKey 결과), dist: 두 꼭짓점 간 거리(m)
class _GraphEdge {
  final String to;
  final double dist;
  _GraphEdge(this.to, this.dist);
}

// Dijkstra 우선순위 큐 항목
// dist 기준 오름차순 정렬을 위해 Comparable 을 구현한다
class _PQEntry implements Comparable<_PQEntry> {
  final String key;
  final double dist;
  _PQEntry(this.key, this.dist);
  @override
  int compareTo(_PQEntry other) => dist.compareTo(other.dist);
}

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

  // 도로를 따라 이어진 전체 경로 기준 거리 합산 결과 (km 단위)
  final double totalDistanceKm;

  // 도로 자동 추종(AutoSnap) 기능 활성화 여부
  final bool autoSnap;

  // 서버 저장 요청 진행 중 여부 (버튼 비활성화·스피너 표시용)
  final bool isSaving;

  // 저장 실패 시 설정되는 오류 메시지
  final String? saveError;

  // 현재 뷰포트에 주행 가능 도로가 로드된 상태인지 여부
  // true 이면 도로 밖 탭이 차단됨을 UI 에서 안내할 수 있다
  final bool hasWays;

  const CourseEditorState({
    this.courseName = '새 코스',
    this.nodes = const [],
    this.undoStack = const [],
    this.redoStack = const [],
    this.totalDistanceKm = 0.0,
    this.autoSnap = false,
    this.isSaving = false,
    this.saveError,
    this.hasWays = false,
  });

  CourseEditorState copyWith({
    String? courseName,
    List<NLatLng>? nodes,
    List<List<NLatLng>>? undoStack,
    List<List<NLatLng>>? redoStack,
    double? totalDistanceKm,
    bool? autoSnap,
    bool? isSaving,
    bool? hasWays,
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
      hasWays: hasWays ?? this.hasWays,
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
// · Dijkstra 그래프 기반 도로 추종 경로 계산
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

  // 주행 가능 도로 오버레이 목록 (지우기 전용)
  final List<NPolylineOverlay> _wayOverlays = [];

  // 스냅·라우팅 계산용 도로 좌표 목록 (_wayOverlays 와 1:1 대응)
  final List<List<NLatLng>> _wayCoordinates = [];

  // 이미 그려진 세그먼트 지문 집합 (시작·끝 좌표 문자열)
  // 같은 osmId 가 여러 세그먼트로 분할 반환되므로 osmId 대신 좌표로 중복 판단
  final Set<String> _drawnSegmentKeys = {};

  // 오버레이 고유 ID 생성용 카운터 (같은 osmId 세그먼트마다 다른 ID 부여)
  int _wayOverlaySeq = 0;

  // Dijkstra 라우팅 그래프
  // 키: "${lat},${lng}" 문자열, 값: 인접 꼭짓점으로 가는 엣지 목록
  final Map<String, List<_GraphEdge>> _graph = {};

  // 그래프 꼭짓점 키 → 좌표 역방향 조회 (경로 복원 시 사용)
  final Map<String, NLatLng> _graphNodes = {};

  // 마지막으로 계산된 도로 추종 전체 경로 좌표
  // 노드 간 Dijkstra 경로를 이어붙인 결과이며, 저장 시 points 로 전달한다
  List<NLatLng> _currentRouteCoords = [];

  // 탭 지점에서 이 거리(m) 이내의 도로만 노드 추가를 허용
  static const _kSnapThresholdM = 30.0;

  // 뷰포트 바운딩 박스에 추가하는 여백 (도 단위, 약 300m)
  // 화면 경계에 걸친 도로가 중간에 끊겨 보이는 현상을 방지
  static const _kBoundsPaddingDeg = 0.003;

  @override
  CourseEditorState build() {
    // 노티파이어 파기 시 지도 오버레이만 정리한다 (state 갱신은 하지 않음)
    // state 를 건드리면 Riverpod 이 StateError 를 던지므로 별도 메서드 사용
    ref.onDispose(() {
      _disposeOverlays();
      // 경로 폴리라인도 정리 (state 접근 없이 SDK 에서만 제거)
      if (_mapController != null && _routeLine != null) {
        _mapController!.deleteOverlay(_routeLine!.info);
        _routeLine = null;
      }
    });
    return const CourseEditorState();
  }

  // 지도 컨트롤러 등록 (onMapReady 콜백에서 1회 호출)
  // map_view.dart 에서 컨트롤러 등록을 카메라 이동보다 먼저 수행하므로
  // 위치 이동 완료 후 발생하는 onCameraIdle 에서 loadWays 가 정상 실행된다
  void setMapController(NaverMapController controller) {
    _mapController = controller;
  }

  // 코스 이름 변경 (상단 바 편집 다이얼로그에서 호출)
  void setCourseName(String name) {
    state = state.copyWith(courseName: name);
  }

  // 지도 탭 → 새 노드 추가
  // 도로 그래프가 로드돼 있으면 탭 지점에서 30m 이내의 가장 가까운
  // 도로 꼭짓점에 스냅하고, 이전 노드에서 그 꼭짓점까지 Dijkstra 로
  // 도로 위 최단 경로를 그린다.
  // 반환값: true = 노드 추가됨, false = 도로 30m 밖 탭으로 차단됨
  bool addNode(NLatLng tapPoint) {
    final NLatLng point;
    if (_wayCoordinates.isNotEmpty) {
      final snapped = _snapToNearestVertex(tapPoint);
      if (snapped == null) return false; // 도로 30m 밖 탭은 무시
      point = snapped;
    } else {
      point = tapPoint; // 도로 미표시 상태의 폴백
    }
    final newUndo = [...state.undoStack, List<NLatLng>.from(state.nodes)];
    final newNodes = [...state.nodes, point];
    state = state.copyWith(
      nodes: newNodes,
      undoStack: newUndo,
      redoStack: [], // 새 동작이 생기면 redo 이력 초기화
      totalDistanceKm: _calcDistance(newNodes),
    );
    _drawRoute(newNodes);
    return true;
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

  // 모든 노드·스택·전체 경로 초기화 + 지도 폴리라인 제거
  void reset() {
    _clearPolyline();
    _currentRouteCoords = [];
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

  // ── 저장 1단계: 화면이 캡처를 시작하기 직전에 호출 ──────────────────
  // isSaving 플래그를 올려 저장 버튼을 비활성화하고 로딩 표시를 켠다.
  // 실제 API 호출은 캡처·업로드가 끝난 뒤 saveCourse() 가 담당한다.
  void startCapture() {
    if (state.nodes.isEmpty) return;
    state = state.copyWith(isSaving: true, saveError: null);
  }

  // ── 저장 2단계: 이미지 업로드 완료 후 코스 저장 API 호출 ─────────────
  // trackImageUrl: TrackSnapshotMap 캡처 → POST /api/v1/tracks/image 업로드 결과
  Future<void> saveCourse({String? trackImageUrl}) async {
    // 도로를 따라가는 전체 좌표가 있으면 그것을, 없으면 스냅 노드만 사용
    final pathPoints =
        _currentRouteCoords.isNotEmpty ? _currentRouteCoords : state.nodes;

    // 지도 SDK 타입(NLatLng) → 도메인 타입(shared.LatLng) 변환
    final domainPoints = pathPoints
        .map((p) => shared.LatLng(latitude: p.latitude, longitude: p.longitude))
        .toList();

    final course = Course(
      title: state.courseName,
      distance: state.totalDistanceKm,
      points: domainPoints,
    );

    try {
      await _repository.saveCourse(course, trackImageUrl: trackImageUrl);
      state = state.copyWith(isSaving: false);
      reset(); // 저장 성공 후 편집 상태를 초기화
    } on ApiException catch (e) {
      state = state.copyWith(isSaving: false, saveError: e.message);
    } catch (_) {
      // ApiException 이외의 예외 (JSON 파싱 오류 등) 를 일반 메시지로 처리
      state = state.copyWith(isSaving: false, saveError: '저장 중 오류가 발생했습니다');
    }
  }

  // ── 저장 실패 처리: 캡처 또는 업로드 단계에서 에러가 발생했을 때 ────────
  void failSave(String message) {
    state = state.copyWith(isSaving: false, saveError: message);
  }

  // 노드 목록으로 도로를 따라가는 경로 폴리라인을 그린다
  // 인접 노드 쌍마다 Dijkstra 최단 경로를 구해 이어붙인 뒤 오버레이로 표시한다
  // 계산된 전체 경로 좌표는 _currentRouteCoords 에 보관해 저장 시 재사용한다
  void _drawRoute(List<NLatLng> nodes) {
    if (_mapController == null) return;
    _clearPolyline();
    if (nodes.length < 2) return;

    final coords = _buildFullRoute(nodes);
    _currentRouteCoords = coords;

    // 직선 노드 거리 대신 실제 도로 추종 거리로 totalDistanceKm 를 갱신한다
    final routeDist = _calcDistance(coords);
    if ((routeDist - state.totalDistanceKm).abs() > 0.001) {
      state = state.copyWith(totalDistanceKm: routeDist);
    }

    _routeLine = NPolylineOverlay(
      id: 'editor_route',
      coords: coords,
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

  // 카메라가 멈출 때마다 호출된다 (CourseEditorMapView 의 onCameraIdle 에서 연결)
  // 줌 14 이상이면 현재 뷰포트의 주행 가능 도로를 불러와 지도에 표시한다
  // (지도 초기 진입 시 기본 줌이 14~15 이므로 별도 확대 없이 바로 표시됨)
  Future<void> loadWays() async {
    if (_mapController == null) return;
    try {
      // 현재 카메라 위치와 줌 레벨을 조회한다
      final position = await _mapController!.getCameraPosition();
      if (position.zoom < 14) {
        // 줌 13 이하에서는 새로 요청하지 않는다
        // 기존에 로드된 도로는 유지해 사용자가 다시 확대했을 때 즉시 표시된다
        return;
      }
      // 현재 화면에 보이는 지도 범위를 조회한다
      // _kBoundsPaddingDeg 여백을 추가해 화면 경계 도로가 중간에 끊기지 않도록 한다
      final bounds = await _mapController!.getContentBounds();
      final ways = await _repository.getWays(
        minLat: bounds.southWest.latitude - _kBoundsPaddingDeg,
        minLng: bounds.southWest.longitude - _kBoundsPaddingDeg,
        maxLat: bounds.northEast.latitude + _kBoundsPaddingDeg,
        maxLng: bounds.northEast.longitude + _kBoundsPaddingDeg,
        zoom: position.zoom.toInt(),
      );
      _drawWays(ways);
    } on ApiException {
      // 도로 데이터 로드 실패는 조용히 무시한다 (보조 기능이므로 UX 방해 최소화)
    } catch (_) {
      // SDK 호출 실패 등 예상치 못한 오류도 무시
    }
  }

  // 도로 목록을 지도에 연한 파랑 폴리라인으로 그린다
  // GeoJSON 좌표는 [경도, 위도] 순이므로 NLatLng(위도, 경도) 로 변환해야 한다
  // 같은 osmId 가 여러 세그먼트로 분할될 수 있으므로 시작·끝 좌표로 중복 판단한다
  // addOverlay 는 fire-and-forget 으로 호출한다:
  //   await 를 걸면 각 await 사이에 다른 이벤트가 끼어들어 카운터/상태가
  //   꼬이고 결과적으로 아무 선도 그려지지 않는 문제가 재현됨
  // 새로운 세그먼트가 추가될 때만 라우팅 그래프를 재구축해 스냅·경로 계산에 반영한다
  void _drawWays(List<Way> ways) {
    if (_mapController == null) return;
    bool addedNew = false;
    for (final way in ways) {
      if (way.geom.coordinates.length < 2) continue;
      final key = _segmentKey(way.geom.coordinates);
      if (_drawnSegmentKeys.contains(key)) continue;
      _drawnSegmentKeys.add(key);

      final coords = way.geom.coordinates
          .map((c) => NLatLng(c[1], c[0])) // [lng, lat] → NLatLng(lat, lng)
          .toList();
      final overlay = NPolylineOverlay(
        id: 'way_${_wayOverlaySeq++}',
        coords: coords,
        color: const Color(0xFF90CAF9), // 연한 파랑으로 도로를 표시
        width: 4,
      );
      _wayOverlays.add(overlay);
      _wayCoordinates.add(coords);
      _mapController!.addOverlay(overlay); // fire-and-forget
      addedNew = true;
    }
    // 새 세그먼트가 추가됐을 때만 그래프를 재구축한다
    if (addedNew) _buildGraph();
    if (_wayCoordinates.isNotEmpty && !state.hasWays) {
      state = state.copyWith(hasWays: true);
    }
  }

  // 오버레이와 라우팅 그래프를 정리한다 (state 갱신 없음 — onDispose 에서 사용)
  void _disposeOverlays() {
    if (_mapController == null) return;
    for (final overlay in _wayOverlays) {
      _mapController!.deleteOverlay(overlay.info);
    }
    _wayOverlays.clear();
    _wayCoordinates.clear();
    _drawnSegmentKeys.clear();
    _wayOverlaySeq = 0;
    _graph.clear();
    _graphNodes.clear();
  }

  // 로드된 도로 꼭짓점을 노드로, 인접 꼭짓점 간 거리(m)를 가중치로 하는
  // 양방향 그래프를 구축한다. _wayCoordinates 가 갱신될 때마다 재호출된다
  void _buildGraph() {
    _graph.clear();
    _graphNodes.clear();
    for (final coords in _wayCoordinates) {
      for (int i = 0; i < coords.length - 1; i++) {
        final a = coords[i];
        final b = coords[i + 1];
        final ka = _latlngKey(a);
        final kb = _latlngKey(b);
        _graphNodes[ka] = a;
        _graphNodes[kb] = b;
        final d = _haversineKm(a, b) * 1000; // m 단위
        _graph.putIfAbsent(ka, () => []).add(_GraphEdge(kb, d));
        _graph.putIfAbsent(kb, () => []).add(_GraphEdge(ka, d));
      }
    }
  }

  // 연속 노드 쌍마다 Dijkstra 로 도로 위 최단 경로를 구해 이어붙인다
  // 그래프에 경로가 없는 쌍은 직선으로 연결한다 (폴백)
  List<NLatLng> _buildFullRoute(List<NLatLng> nodes) {
    if (nodes.length < 2) return List.of(nodes);
    final result = <NLatLng>[nodes.first];
    for (int i = 0; i < nodes.length - 1; i++) {
      final path = _findPath(nodes[i], nodes[i + 1]);
      if (path != null && path.length > 1) {
        result.addAll(path.skip(1)); // 시작점 중복 방지
      } else {
        result.add(nodes[i + 1]); // 라우팅 실패 시 직선으로 연결
      }
    }
    return result;
  }

  // Dijkstra 알고리즘으로 그래프 상의 from → to 최단 경로 좌표 목록을 반환한다
  // 두 꼭짓점이 같거나 경로가 없으면 null 을 반환한다
  List<NLatLng>? _findPath(NLatLng from, NLatLng to) {
    final startKey = _latlngKey(from);
    final endKey = _latlngKey(to);
    if (startKey == endKey) return [from];
    if (!_graph.containsKey(startKey) || !_graph.containsKey(endKey)) {
      return null;
    }

    final dist = <String, double>{startKey: 0.0};
    final prev = <String, String?>{};
    // List 를 정렬해 최솟값을 꺼내는 단순 구현 (뷰포트 내 수백 개 노드에 충분)
    final open = <_PQEntry>[_PQEntry(startKey, 0.0)];

    while (open.isNotEmpty) {
      open.sort();
      final cur = open.removeAt(0);
      if (cur.key == endKey) break;
      final curDist = dist[cur.key]!;
      for (final edge in _graph[cur.key] ?? []) {
        final nd = curDist + edge.dist;
        if (nd < (dist[edge.to] ?? double.infinity)) {
          dist[edge.to] = nd;
          prev[edge.to] = cur.key;
          open.add(_PQEntry(edge.to, nd));
        }
      }
    }

    if (!prev.containsKey(endKey)) return null;
    // prev 를 역추적해 경로를 복원한다
    final path = <NLatLng>[];
    String? k = endKey;
    while (k != null) {
      path.add(_graphNodes[k]!);
      k = prev[k];
    }
    return path.reversed.toList();
  }

  // 탭 지점에서 가장 가까운 도로 꼭짓점을 반환한다
  // 꼭짓점에 스냅해야 _graph 에서 Dijkstra 시작/끝 노드를 정확히 찾을 수 있다
  // _kSnapThresholdM 초과이면 null 을 반환해 노드 추가를 차단한다
  NLatLng? _snapToNearestVertex(NLatLng tap) {
    NLatLng? best;
    double bestDist = double.infinity;
    for (final coords in _wayCoordinates) {
      for (final coord in coords) {
        final d = _haversineKm(tap, coord) * 1000; // m 단위
        if (d < bestDist) {
          bestDist = d;
          best = coord;
        }
      }
    }
    return (bestDist <= _kSnapThresholdM) ? best : null;
  }

  // 좌표를 그래프 키로 변환한다 (부동소수점 동등 비교를 문자열 비교로 대체)
  String _latlngKey(NLatLng p) => '${p.latitude},${p.longitude}';

  // 세그먼트 지문: 시작·끝 좌표를 문자열로 결합해 동일 세그먼트를 식별
  String _segmentKey(List<List<double>> coords) {
    final s = coords.first;
    final e = coords.last;
    return '${s[0]}_${s[1]}_${e[0]}_${e[1]}';
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

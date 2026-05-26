import 'dart:math';

import 'package:flutter/material.dart' show Color, Colors;
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

// 도로 선분 위 최근접 스냅 결과
// point: 실제 노드로 추가할 선분 위 좌표
// segmentStart/segmentEnd: 임시 그래프 연결을 위한 선분 양 끝 좌표
class _SnapResult {
  final NLatLng point;
  final NLatLng segmentStart;
  final NLatLng segmentEnd;

  _SnapResult({
    required this.point,
    required this.segmentStart,
    required this.segmentEnd,
  });
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

  // 도로 데이터 요청 진행 여부
  // 로딩 중 탭 입력 차단 안내에 사용되는 상태
  final bool isLoadingWays;

  // 현재 줌 레벨이 도로 데이터 로드 임계값(15) 미만인지 여부
  // true 이면 "더 가까이 확대해 주세요" 안내를 UI 에서 표시한다
  final bool isZoomTooLow;

  // 챌린지 컨텍스트에서 진입 시 설정 — 저장 시 POST 바디에 포함
  // null 이면 일반 코스 저장 (challengeId 없이 전송)
  final int? challengeId;

  // 직전 저장 성공 시 BE 가 발급한 courseDraftId.
  // "달리기 시작" 다이얼로그가 이 값을 꺼내 RunningNotifier.setSessionContext 에 전달한다.
  // 다음 저장 호출에서 덮어써진다 — 다이얼로그가 닫히기 전까지만 의미 있는 값.
  final int? savedCourseDraftId;

  // 다익스트라가 만든 도로 추종 전체 경로 좌표.
  // nodes 가 N개여도 두 점 사이를 도로 vertex 들로 이어 풍부한 좌표 시퀀스가 들어 있다.
  // - 화면 폴리라인 / 트랙 캡처(TrackSnapshotMap) / 저장 시 BE 전송 좌표 모두 이 값을 사용해
  //   "두 점만 찍어도 직선으로 건물 관통" 케이스가 없도록 한다.
  // - nodes 가 1개 이하면 빈 리스트 (다익스트라가 돌 일이 없음).
  final List<NLatLng> routeCoords;

  const CourseEditorState({
    this.courseName = '5월 3주차 EASY 코스',
    this.nodes = const [],
    this.undoStack = const [],
    this.redoStack = const [],
    this.totalDistanceKm = 0.0,
    this.autoSnap = false,
    this.isSaving = false,
    this.saveError,
    this.hasWays = false,
    this.isLoadingWays = false,
    this.isZoomTooLow = false,
    this.challengeId,
    this.savedCourseDraftId,
    this.routeCoords = const [],
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
    bool? isLoadingWays,
    bool? isZoomTooLow,
    int? challengeId,
    int? savedCourseDraftId,
    List<NLatLng>? routeCoords,
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
      isLoadingWays: isLoadingWays ?? this.isLoadingWays,
      isZoomTooLow: isZoomTooLow ?? this.isZoomTooLow,
      challengeId: challengeId ?? this.challengeId,
      savedCourseDraftId: savedCourseDraftId ?? this.savedCourseDraftId,
      routeCoords: routeCoords ?? this.routeCoords,
      saveError: saveError == _sentinel ? this.saveError : saveError as String?,
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

  // 노드 위치 마커 오버레이 목록 (지우기 전용)
  final List<NCircleOverlay> _nodeOverlays = [];

  // 스냅·라우팅 계산용 도로 좌표 목록 (_wayOverlays 와 1:1 대응)
  final List<List<NLatLng>> _wayCoordinates = [];

  // 이미 그려진 세그먼트 지문 집합 (시작·끝 좌표 문자열)
  // 같은 osmId 가 여러 세그먼트로 분할 반환되므로 osmId 대신 좌표로 중복 판단
  final Set<String> _drawnSegmentKeys = {};

  // 오버레이 고유 ID 생성용 카운터 (같은 osmId 세그먼트마다 다른 ID 부여)
  int _wayOverlaySeq = 0;

  // 도로 데이터 요청 순번
  // 늦게 도착한 이전 뷰포트 응답 무시를 위한 기준값
  int _loadWaysRequestSeq = 0;

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
  // 위치 이동 완료 후 발생하는 onCameraIdle 에서 loadWays 가 정상 실행된다.
  // loadNodes 가 먼저 호출된 경우 여기서 경로를 그린다.
  void setMapController(NaverMapController controller) {
    _mapController = controller;
    if (state.nodes.isNotEmpty) _drawRoute(state.nodes);
  }

  // 기존 코스의 좌표를 에디터에 미리 채운다 (이어서 편집 진입 시 호출)
  // setMapController 보다 먼저 호출될 수 있으므로 컨트롤러 준비 여부를 확인한다
  void loadNodes(List<NLatLng> nodes) {
    if (nodes.isEmpty) return;
    state = state.copyWith(
      nodes: nodes,
      undoStack: [],
      redoStack: [],
      totalDistanceKm: _calcDistance(nodes),
    );
    // 컨트롤러가 이미 준비된 경우에만 즉시 그린다
    if (_mapController != null) _drawRoute(nodes);
  }

  // courseDraftId 로 상세 API 를 조회해 기존 좌표를 에디터에 채운다
  // 관리 화면 편집 버튼 → initialNodes 없이 진입 시 호출
  Future<void> loadFromId(int courseDraftId) async {
    try {
      final detail = await _repository.getEditorDetail(courseDraftId);
      if (detail.coordinates.isEmpty) return;
      final nNodes = detail.coordinates
          .map((e) => NLatLng(e.latitude, e.longitude))
          .toList();
      loadNodes(nNodes);
    } catch (_) {
      // 조회 실패 시 빈 상태로 편집 시작 (무시)
    }
  }

  // 코스 이름 변경 (상단 바 편집 다이얼로그에서 호출)
  void setCourseName(String name) {
    state = state.copyWith(courseName: name);
  }

  // 지도 탭 → 새 노드 추가
  // 도로 그래프가 로드돼 있으면 탭 지점에서 30m 이내의 가장 가까운
  // 도로 선분 위 지점에 스냅하고, 이전 노드에서 해당 지점까지 Dijkstra 로
  // 도로 위 최단 경로 구성
  // 반환값: true = 노드 추가됨, false = 도로 미로딩 또는 30m 밖 탭 차단
  bool addNode(NLatLng tapPoint) {
    if (_wayCoordinates.isEmpty) return false; // 도로 데이터 로딩 전 입력 차단
    final snapped = _snapToNearestSegment(tapPoint);
    if (snapped == null) return false; // 도로 30m 밖 탭 차단
    final point = snapped.point;
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

  // 모든 노드·스택·전체 경로 초기화 + 지도 폴리라인·마커 제거
  void reset() {
    _clearPolyline();
    _clearNodeOverlays();
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

  // 챌린지 컨텍스트에서 에디터 진입 시 화면 initState 에서 한 번 호출
  // state 에 challengeId 를 저장해 두면 saveCourse 가 POST 바디에 포함시킴
  void setChallengeId(int? id) {
    state = state.copyWith(challengeId: id);
  }

  // ── 저장 1단계: 화면이 캡처를 시작하기 직전에 호출 ──────────────────
  // isSaving 플래그를 올려 저장 버튼을 비활성화하고 로딩 표시를 켠다.
  // 실제 API 호출은 캡처·업로드가 끝난 뒤 saveCourse() 가 담당한다.
  void startCapture() {
    if (state.nodes.isEmpty) return;
    state = state.copyWith(isSaving: true, saveError: null);
  }

  // ── 저장 2단계: 캡처 완료 후 코스 저장 API 호출 ──────────────────────
  // thumbnailBase64: TrackSnapshotMap 이 캡처한 PNG 를 base64 인코딩한 문자열
  Future<void> saveCourse({String? thumbnailBase64}) async {
    // 도로를 따라가는 전체 좌표가 있으면 그것을, 없으면 스냅 노드만 사용
    final pathPoints = _currentRouteCoords.isNotEmpty
        ? _currentRouteCoords
        : state.nodes;

    // 지도 SDK 타입(NLatLng) → 도메인 타입(shared.LatLng) 변환
    final domainPoints = pathPoints
        .map((p) => shared.LatLng(latitude: p.latitude, longitude: p.longitude))
        .toList();

    final course = Course(
      title: state.courseName,
      distance: state.totalDistanceKm,
      points: domainPoints,
      challengeId: state.challengeId, // null 이면 toJson 에서 필드 생략
    );

    try {
      // 저장 성공 시 BE 가 발급한 courseDraftId 를 받는다.
      // reset() 이 다른 state 필드를 비우므로 ID 보관은 reset 직후에 한 번 더 갱신.
      // 화면(_askToStartRun) 이 이 값을 꺼내 RunningNotifier.setSessionContext 에 전달한다.
      final draftId = await _repository.saveCourse(
        course,
        thumbnailBase64: thumbnailBase64,
      );
      reset();
      state = state.copyWith(isSaving: false, savedCourseDraftId: draftId);
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
    _clearNodeOverlays();

    if (nodes.length < 2) {
      _currentRouteCoords = [];
      if (state.routeCoords.isNotEmpty) {
        state = state.copyWith(routeCoords: const []);
      }
      // 노드가 1개여도 마커는 표시한다
      _drawNodeMarkers(nodes);
      return;
    }

    final coords = _buildFullRoute(nodes);
    _currentRouteCoords = coords;

    // 직선 노드 거리 대신 실제 도로 추종 거리로 totalDistanceKm 를 갱신한다
    // routeCoords 도 함께 state 에 노출 — TrackSnapshotMap 이 도로 따라가는 좌표로 캡처할 수 있도록.
    final routeDist = _calcDistance(coords);
    state = state.copyWith(
      totalDistanceKm: routeDist,
      routeCoords: coords,
    );

    _routeLine = NPolylineOverlay(
      id: 'editor_route',
      coords: coords,
      color: kCourseRouteColor, // 경로 색상 (주황-빨강)
      width: 6,
    );
    _mapController!.addOverlay(_routeLine!);
    // 폴리라인 위에 노드 마커를 그려 노드 위치를 시각적으로 표시
    _drawNodeMarkers(nodes);
  }

  // 기존 폴리라인 오버레이를 지도에서 제거
  void _clearPolyline() {
    if (_mapController != null && _routeLine != null) {
      _mapController!.deleteOverlay(_routeLine!.info);
      _routeLine = null;
    }
  }

  // 노드 마커 오버레이를 지도에서 제거
  void _clearNodeOverlays() {
    if (_mapController == null) return;
    for (final o in _nodeOverlays) {
      _mapController!.deleteOverlay(o.info);
    }
    _nodeOverlays.clear();
  }

  // 노드 목록을 지도에 원형 마커로 표시
  // 첫 번째 노드는 시작점으로 크게, 나머지는 작게 표시
  // globalZIndex 를 폴리라인(-100000)보다 높게 설정해 도보 레이어 위에 표시
  void _drawNodeMarkers(List<NLatLng> nodes) {
    if (_mapController == null || nodes.isEmpty) return;
    for (int i = 0; i < nodes.length; i++) {
      final isFirst = i == 0;
      final overlay = NCircleOverlay(
        id: 'node_marker_$i',
        center: nodes[i],
        radius: isFirst ? 8.0 : 5.0,
        color: isFirst ? kCourseRouteColor : Colors.white,
        outlineColor: kCourseRouteColor,
        outlineWidth: 1.5,
      )..setGlobalZIndex(0); // 도보·경로 폴리라인(-100000)보다 위에 렌더링
      _nodeOverlays.add(overlay);
      _mapController!.addOverlay(overlay);
    }
  }

  // 도로 데이터 로드 최소 줌 레벨
  // 이 값 미만에서는 뷰포트가 너무 넓어 응답 지연이 심각하므로 로드하지 않는다
  // (줌 15: 약 1km × 0.7km 뷰포트, 줌 14: 약 2km × 1.4km — 데이터량 4배 차이)
  static const _kMinLoadZoom = 15;

  // 카메라가 멈출 때마다 호출된다 (CourseEditorMapView 의 onCameraIdle 에서 연결)
  // 줌 15 이상에서만 도로를 요청한다 — 그 미만은 뷰포트가 너무 넓어 로드가 느려짐
  Future<void> loadWays() async {
    if (_mapController == null) return;
    final requestSeq = ++_loadWaysRequestSeq;
    try {
      // 현재 카메라 위치와 줌 레벨을 조회한다
      final position = await _mapController!.getCameraPosition();
      if (requestSeq != _loadWaysRequestSeq) return;
      if (position.zoom < _kMinLoadZoom) {
        // 임계 줌 미만: 로드 중단 + 줌 부족 상태를 UI 에 알린다
        // 이미 로드된 도로 오버레이는 유지해 재확대 시 즉시 표시된다
        state = state.copyWith(isZoomTooLow: true, isLoadingWays: false);
        return;
      }
      // 줌 충분: 줌 부족 상태 해제 후 로드 시작
      state = state.copyWith(isZoomTooLow: false, isLoadingWays: true);
      // 현재 화면에 보이는 지도 범위를 조회한다
      // _kBoundsPaddingDeg 여백을 추가해 화면 경계 도로가 중간에 끊기지 않도록 한다
      final bounds = await _mapController!.getContentBounds();
      if (requestSeq != _loadWaysRequestSeq) return;
      final ways = await _repository.getWays(
        minLat: bounds.southWest.latitude - _kBoundsPaddingDeg,
        minLng: bounds.southWest.longitude - _kBoundsPaddingDeg,
        maxLat: bounds.northEast.latitude + _kBoundsPaddingDeg,
        maxLng: bounds.northEast.longitude + _kBoundsPaddingDeg,
        zoom: position.zoom.toInt(),
      );
      if (requestSeq != _loadWaysRequestSeq) return;
      _drawWays(ways);
    } on ApiException {
      // 도로 데이터 로드 실패는 조용히 무시한다 (보조 기능이므로 UX 방해 최소화)
    } catch (_) {
      // SDK 호출 실패 등 예상치 못한 오류도 무시
    } finally {
      if (requestSeq == _loadWaysRequestSeq) {
        state = state.copyWith(isLoadingWays: false);
      }
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
    for (final o in _nodeOverlays) {
      _mapController!.deleteOverlay(o.info);
    }
    _nodeOverlays.clear();
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
    // 같은 도로 분기점이지만 way 끝점 좌표가 부동소수점 / BE 직렬화 정밀도 차이로
    // 서로 다른 NLatLng 이 되어 키가 갈리는 경우가 잦다.
    // 7자리 라운딩(_latlngKey) 만으로는 잡지 못한 케이스를 거리 기반으로 봉합한다.
    _bridgeNearbyNodes();
  }

  // 그래프 노드 중 매우 가까운(분기점 후보) 쌍을 직접 엣지로 연결.
  // 라운딩으로 같은 키가 못 된 분기점들을 이 단계에서 사실상 같은 노드처럼 잇는다.
  // 임계값 5m — 도로 분기점 자체는 같은 좌표여야 하지만 잔차로 1~3m 차이 나는 경우까지 흡수.
  // O(N^2) 이지만 뷰포트 내 N=수백 수준이라 비용 무시 가능.
  void _bridgeNearbyNodes() {
    const double bridgeThresholdM = 5.0;
    final keys = _graphNodes.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      final ka = keys[i];
      final a = _graphNodes[ka]!;
      for (int j = i + 1; j < keys.length; j++) {
        final kb = keys[j];
        final b = _graphNodes[kb]!;
        final d = _haversineKm(a, b) * 1000;
        if (d <= bridgeThresholdM) {
          _graph.putIfAbsent(ka, () => []).add(_GraphEdge(kb, d));
          _graph.putIfAbsent(kb, () => []).add(_GraphEdge(ka, d));
        }
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

  // Dijkstra 알고리즘 기반 from → to 최단 경로 좌표 목록
  // 선분 위 스냅 좌표를 임시 노드로 연결해 끝점 쏠림 없이 경로 복원
  List<NLatLng>? _findPath(NLatLng from, NLatLng to) {
    final fromSnap = _snapToNearestSegment(from);
    final toSnap = _snapToNearestSegment(to);
    if (fromSnap == null || toSnap == null) return null;
    if (_isSameSegment(fromSnap, toSnap)) {
      return [fromSnap.point, toSnap.point];
    }

    final graph = <String, List<_GraphEdge>>{
      for (final entry in _graph.entries) entry.key: List.of(entry.value),
    };
    final graphNodes = Map<String, NLatLng>.of(_graphNodes);

    final startKey = _attachPointToGraph(from, graph, graphNodes);
    final endKey = _attachPointToGraph(to, graph, graphNodes);
    if (startKey == null || endKey == null) return null;
    if (startKey == endKey) return [graphNodes[startKey]!];

    final dist = <String, double>{startKey: 0.0};
    final prev = <String, String?>{};
    // List 를 정렬해 최솟값을 꺼내는 단순 구현 (뷰포트 내 수백 개 노드에 충분)
    final open = <_PQEntry>[_PQEntry(startKey, 0.0)];

    while (open.isNotEmpty) {
      open.sort();
      final cur = open.removeAt(0);
      if (cur.key == endKey) break;
      final curDist = dist[cur.key]!;
      for (final edge in graph[cur.key] ?? []) {
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
      path.add(graphNodes[k]!);
      k = prev[k];
    }
    return path.reversed.toList();
  }

  // 두 스냅 지점의 기준 도로 선분 동일 여부
  // 같은 선분 위 노드 간 끝점 우회 방지를 위한 비교
  bool _isSameSegment(_SnapResult a, _SnapResult b) {
    final aStart = _latlngKey(a.segmentStart);
    final aEnd = _latlngKey(a.segmentEnd);
    final bStart = _latlngKey(b.segmentStart);
    final bEnd = _latlngKey(b.segmentEnd);
    return (aStart == bStart && aEnd == bEnd) ||
        (aStart == bEnd && aEnd == bStart);
  }

  // 탭 지점에서 가장 가까운 도로 선분 위 좌표 반환
  // 꼭짓점이 아닌 선분 투영 좌표 사용으로 끝점 쏠림 완화
  // _kSnapThresholdM 초과이면 null 반환을 통한 노드 추가 차단
  _SnapResult? _snapToNearestSegment(NLatLng tap) {
    _SnapResult? best;
    double bestDist = double.infinity;
    for (final coords in _wayCoordinates) {
      for (int i = 0; i < coords.length - 1; i++) {
        final a = coords[i];
        final b = coords[i + 1];
        final point = _closestPointOnSegment(tap, a, b);
        final d = _haversineKm(tap, point) * 1000; // m 단위
        if (d < bestDist) {
          bestDist = d;
          best = _SnapResult(point: point, segmentStart: a, segmentEnd: b);
        }
      }
    }
    return (bestDist <= _kSnapThresholdM) ? best : null;
  }

  // 임의의 스냅 좌표를 Dijkstra 임시 그래프에 연결
  // 선분 양 끝점과의 양방향 엣지 추가를 통한 경로 탐색 준비
  String? _attachPointToGraph(
    NLatLng point,
    Map<String, List<_GraphEdge>> graph,
    Map<String, NLatLng> graphNodes,
  ) {
    final pointKey = _latlngKey(point);
    if (graph.containsKey(pointKey)) return pointKey;

    final snapped = _snapToNearestSegment(point);
    if (snapped == null) return null;

    final startKey = _latlngKey(snapped.segmentStart);
    final endKey = _latlngKey(snapped.segmentEnd);
    if (!graph.containsKey(startKey) || !graph.containsKey(endKey)) {
      return null;
    }

    graphNodes[pointKey] = snapped.point;
    graph.putIfAbsent(pointKey, () => []);

    final startDist = _haversineKm(snapped.point, snapped.segmentStart) * 1000;
    final endDist = _haversineKm(snapped.point, snapped.segmentEnd) * 1000;
    graph[pointKey]!.add(_GraphEdge(startKey, startDist));
    graph[pointKey]!.add(_GraphEdge(endKey, endDist));
    graph[startKey]!.add(_GraphEdge(pointKey, startDist));
    graph[endKey]!.add(_GraphEdge(pointKey, endDist));

    return pointKey;
  }

  // 위경도 좌표를 로컬 평면 좌표처럼 투영해 선분 위 최근접점 계산
  // 화면 단위의 짧은 도로 선분에서 충분한 근사 정확도 확보
  NLatLng _closestPointOnSegment(NLatLng p, NLatLng a, NLatLng b) {
    final latScale = 111320.0;
    final lngScale = 111320.0 * cos(_toRad((a.latitude + b.latitude) / 2));

    final px = p.longitude * lngScale;
    final py = p.latitude * latScale;
    final ax = a.longitude * lngScale;
    final ay = a.latitude * latScale;
    final bx = b.longitude * lngScale;
    final by = b.latitude * latScale;

    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return a;

    final t = (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
    return NLatLng((ay + dy * t) / latScale, (ax + dx * t) / lngScale);
  }

  // 좌표를 그래프 키로 변환한다 (부동소수점 동등 비교를 문자열 비교로 대체)
  //
  // 두 way 가 만나는 도로 분기점은 OSM 상 같은 좌표여야 하지만, GeoJSON 파싱이나
  // double 산술 결과 미세한 부동소수점 잔차로 11번째 자리에서 차이가 날 수 있다.
  // 그대로 키로 쓰면 분기점이 서로 다른 노드 두 개로 인식되어 그래프가 끊기고,
  // Dijkstra 가 그 분기점을 통과하지 못해 도로 꼭짓점이 누락된 경로가 나온다.
  // 소수점 7자리(~1cm) 까지 라운딩해 같은 분기점 좌표가 항상 같은 키로 매핑되도록 한다.
  String _latlngKey(NLatLng p) =>
      '${p.latitude.toStringAsFixed(7)},${p.longitude.toStringAsFixed(7)}';

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
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.latitude)) *
            cos(_toRad(b.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * asin(sqrt(h));
  }

  double _toRad(double deg) => deg * pi / 180;
}

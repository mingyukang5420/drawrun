import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/presentation/course_editor_viewmodel.dart';
import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/widgets/course_editor_map_view.dart';
import 'package:running/shared/map/widgets/track_snapshot_map.dart';
import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/screen/running_countdown_screen.dart';
import 'package:running/shared/model/lat_lng.dart' as shared;

// 코스 생성·편집 화면
// Scaffold > Stack 구조로 전체화면 지도 위에 UI 레이어를 겹쳐 쌓는다
// 저장 흐름: 저장 버튼 → TrackSnapshotMap 캡처 → 이미지 업로드 → 코스 저장 API
//
// initialNodes 를 넘기면 에디터에 기존 경로를 미리 채워 이어서 편집할 수 있다.
// difficulty 를 넘기면 챌린지 모드로 진입 — 저장 성공 시 달리기 시작 여부를 묻는다
class CourseEditorScreen extends ConsumerStatefulWidget {
  // 상세 조회에서 받은 기존 좌표 목록. null 이면 빈 상태로 시작
  final List<shared.LatLng>? initialNodes;

  // 챌린지 진입 난이도 ('EASY' | 'HARD'). null 이면 일반 코스 생성 모드
  final String? difficulty;

  // 코스에 대응하는 폴리곤 이미지 URL. null 이면 빈 placeholder 를 표시
  final String? polygonImageUrl;

  // 폴리곤 이미지 버튼 전용 타이틀 (코스명과 별개). null 이면 기본 텍스트 표시
  final String? polygonTitle;

  // 챌린지 컨텍스트에서 진입 시 전달 — 저장 시 POST /api/v1/editor 바디에 포함
  // null 이면 일반 코스 저장 (챌린지 ID 없이 전송)
  final int? challengeId;

  // 관리 화면 편집 버튼 진입 시 전달 — initialNodes 대신 ID 로 서버에서 좌표 조회
  // initialNodes 와 동시에 사용하지 않는다
  final int? courseDraftId;

  const CourseEditorScreen({
    super.key,
    this.initialNodes,
    this.difficulty,
    this.polygonImageUrl,
    this.polygonTitle,
    this.challengeId,
    this.courseDraftId,
  });

  @override
  ConsumerState<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends ConsumerState<CourseEditorScreen> {
  // 저장 버튼을 누른 뒤 TrackSnapshotMap 이 Stack 에 올라간 상태
  bool _isCapturing = false;

  // 폴리곤 미리보기 패널 위치 — null 이면 build() 첫 호출 시 초기화
  // right: 화면 우측 끝에서 패널 우측 끝까지의 거리(px)
  // → Positioned.right 로 고정하면 너비 증가 시 자연스럽게 왼쪽으로 확장됨
  double? _polygonRight;
  double? _polygonTop;
  // 폴리곤 미리보기 패널 현재 크기(px) — 48 = 축소 버튼, 큰 값 = 확대 패널
  double _polygonSize = 48;
  // onScaleStart 시점의 크기 스냅샷 — onScaleUpdate 배율 계산 기준
  double _polygonScaleStart = 48;
  // 진입 직후 2초간 힌트 메시지를 패널 하단에 표시
  bool _polygonHintVisible = false;

  @override
  void initState() {
    super.initState();
    // 폴리곤 URL 이 있을 때 진입 직후 패널을 최대 크기로 펼쳐 도형을 보여준다.
    // MediaQuery 는 첫 프레임 이후에만 사용 가능하므로 addPostFrameCallback 으로 지연.
    // 2초 뒤 자동 축소 + 힌트 메시지 숨김.
    if (widget.polygonImageUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final kMax = MediaQuery.of(context).size.width - 16;
        setState(() {
          _polygonSize = kMax;
          _polygonHintVisible = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _polygonSize = 48.0;
            _polygonHintVisible = false;
          });
        });
      });
    }

    // 챌린지 컨텍스트 진입 시 challengeId 를 notifier 에 주입
    // 이유: saveCourse() 가 POST /api/v1/editor 바디에 challengeId 를 포함해야
    //       서버가 챌린지 코스임을 인식할 수 있음. 누락 시 서버가 요청을 거부함.
    final cid = widget.challengeId;
    if (cid != null) {
      Future.microtask(
        () => ref.read(courseEditorProvider.notifier).setChallengeId(cid),
      );
    }

    // 기존 좌표가 있으면 지도 준비 후 에디터에 채운다
    final initial = widget.initialNodes;
    if (initial != null && initial.isNotEmpty) {
      final nNodes = initial
          .map((e) => NLatLng(e.latitude, e.longitude))
          .toList();
      Future.microtask(
        () => ref.read(courseEditorProvider.notifier).loadNodes(nNodes),
      );
    } else if (widget.courseDraftId != null) {
      // initialNodes 없이 courseDraftId 만 전달된 경우 서버에서 좌표 조회
      Future.microtask(
        () => ref
            .read(courseEditorProvider.notifier)
            .loadFromId(widget.courseDraftId!),
      );
    }
  }

  // ── 저장 버튼 콜백 ─────────────────────────────────────────────────
  // 1) Notifier 에 "캡처 시작" 을 알려 isSaving 플래그를 올린다
  // 2) 로컬 _isCapturing 을 true 로 바꿔 Stack 에 TrackSnapshotMap 을 추가한다
  void _onSavePressed() {
    ref.read(courseEditorProvider.notifier).startCapture();
    setState(() => _isCapturing = true);
  }

  // ── TrackSnapshotMap 캡처 성공 콜백 ───────────────────────────────
  // PNG File 을 base64 로 변환한 뒤 thumbnailBase64 로 코스 저장 API 를 호출한다
  Future<void> _onCaptured(File imageFile) async {
    setState(() => _isCapturing = false);

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      await ref
          .read(courseEditorProvider.notifier)
          .saveCourse(thumbnailBase64: base64Str);
    } catch (_) {
      if (!mounted) return;
      ref.read(courseEditorProvider.notifier).failSave('이미지 변환에 실패했습니다');
    }
  }

  // ── TrackSnapshotMap 캡처 실패 콜백 ───────────────────────────────
  void _onCaptureFailed(Object _) {
    setState(() => _isCapturing = false);
    ref.read(courseEditorProvider.notifier).failSave('경로 이미지 생성에 실패했습니다');
  }

  // ── 챌린지 저장 완료 후 달리기 시작 여부 확인 다이얼로그 ──────────────
  void _askToStartRun(BuildContext ctx) {
    // 달리기 시작 버튼 콜백 — 다이얼로그 안에서 ref 를 쓰기 위해 미리 포획
    void onStartRun() {
      // 직전 저장 성공으로 받은 courseDraftId 를 러닝 세션 컨텍스트에 박는다.
      // 주의: setSessionContext 는 명시하지 않은 인자도 null 로 강제 리셋하므로
      // 진입 시 박아 둔 challengeId 도 명시 전달해야 종료 API 에 그대로 실린다.
      final draftId = ref.read(courseEditorProvider).savedCourseDraftId;
      if (draftId != null) {
        final currentChallengeId =
            ref.read(runningViewModelProvider).challengeId;
        ref.read(runningViewModelProvider.notifier).setSessionContext(
              challengeId: currentChallengeId,
              courseDraftId: draftId,
            );
      }
      Navigator.of(ctx)
        ..pop() // 다이얼로그 닫기
        ..pop(); // 에디터 닫기
      Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => const RunningCountdownScreen(),
          fullscreenDialog: true,
        ),
      );
    }

    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 저장 성공 아이콘
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF27AE60),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // 제목
              const Text(
                '코스 저장 완료!',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // 안내 문구
              const Text(
                '지금 바로 이 코스를 달릴까요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // 버튼 행 — 나중에(보조) + 달리기 시작(주)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx)
                        ..pop()
                        ..pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('나중에'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onStartRun,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('달리기 시작'),
                          SizedBox(width: 6),
                          Icon(Icons.play_arrow_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // state 변경 시 화면 전체가 다시 빌드된다
    final state = ref.watch(courseEditorProvider);
    final notifier = ref.read(courseEditorProvider.notifier);

    // isSaving 이 true → false 로 바뀌는 순간을 감지해
    // 저장 성공이면 챌린지 여부에 따라 다이얼로그 또는 팝, 실패면 스낵바를 표시한다
    ref.listen<CourseEditorState>(courseEditorProvider, (prev, next) {
      if (prev?.isSaving == true && !next.isSaving) {
        if (!context.mounted) return;
        if (next.saveError == null) {
          if (widget.difficulty != null) {
            // 챌린지 모드: 저장 성공 후 달리기 시작 여부 확인
            _askToStartRun(context);
          } else {
            Navigator.of(context).pop();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.saveError!)),
          );
        }
      }
    });

    // 에디터 경로 좌표(NLatLng) → TrackSnapshotMap 용 shared.LatLng 로 변환.
    // 다익스트라 결과(state.routeCoords) 가 있으면 그것을 우선 사용 — 두 점만 찍어도 도로를 따라
    // 풍부한 좌표 시퀀스로 캡처되어 "건물 관통 직선" 케이스를 피한다.
    // routeCoords 가 비어있을 때만 (계산 전 / 노드 1개 이하) state.nodes 폴백.
    final snapshotSource =
        state.routeCoords.isNotEmpty ? state.routeCoords : state.nodes;
    final snapshotNodes = snapshotSource
        .map((n) => shared.LatLng(latitude: n.latitude, longitude: n.longitude))
        .toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      // _BottomPanel 을 bottomNavigationBar 로 올려 ScaffoldMessenger 가
      // 스낵바를 패널 위에 자동 배치하도록 한다
      bottomNavigationBar: _BottomPanel(
        state: state,
        notifier: notifier,
        onSave: _onSavePressed,
      ),
      body: Stack(
        children: [
          // 1단계: 전체화면 지도 (가장 아래 레이어)
          const Positioned.fill(
            child: CourseEditorMapView(),
          ),

          // 2단계: 캡처 전용 지도 (저장 버튼을 누른 동안만 Stack 에 올라간다)
          // - Opacity(0): 사용자 눈에는 보이지 않지만 GPU 가 실제로 렌더링 → 스냅샷 가능
          // - IgnorePointer: 캡처 중 편집 지도의 터치 이벤트를 막지 않는다
          if (_isCapturing)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: TrackSnapshotMap(
                    nodes: snapshotNodes,
                    onCaptured: _onCaptured,
                    onCaptureFailed: _onCaptureFailed,
                    polylineColor: kCourseRouteColor,
                  ),
                ),
              ),
            ),

          // 3단계: 상단 타이틀 바 (뒤로가기 + 코스명 + 저장 상태)
          // 폴리곤 패널이 플로팅이므로 right: 0 으로 전체 너비 사용
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _TitleBar(
                state: state,
                onNameTap: () => _showNameDialog(state.courseName),
              ),
            ),
          ),

          // 3-3단계: 총 거리 뱃지 (경로가 있을 때 타이틀 바 하단에 표시)
          if (state.nodes.isNotEmpty)
            Positioned(
              top: 0,
              left: 12,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: _KmBadge(km: state.totalDistanceKm),
                ),
              ),
            ),

          // 4단계: 도로 상태 안내 힌트 배너
          // body 하단이 _BottomPanel 바로 위에서 끝나므로 bottom: 12 로 패널 상단 근처에 배치
          if (state.nodes.isEmpty)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: _RoadHintBanner(hasWays: state.hasWays),
            ),

          // 5단계: 오른쪽 플로팅 버튼 열 (검색·현재위치)
          Positioned(
            right: 12,
            bottom: 12,
            child: _RightFabColumn(
              notifier: notifier,
              onSearchTap: () => _showSearchSheet(notifier),
            ),
          ),

          // 7단계: 폴리곤 미리보기 패널 — Stack 마지막 자식으로 최상위 레이어 보장
          // - GestureDetector.onPanUpdate 로 드래그 이동
          // - GestureDetector.onTap 으로 최소(48) ↔ 최대 크기 전환
          // - Positioned.right 고정 → AnimatedContainer 너비 증가 시 왼쪽으로 자연 확장
          if (widget.polygonImageUrl != null)
            Builder(builder: (context) {
              final q = MediaQuery.of(context);
              // 최대 크기: 타이틀 입력 너비와 동일 (좌우 여백 각 8px 제외)
              final double kMax = q.size.width - 16;
              // 최초 1회 초기화 — 타이틀 바 아래 우측 끝 (right: 8, top: 타이틀 바 하단)
              _polygonRight ??= 8.0;
              _polygonTop   ??= q.padding.top + 68.0;

              return Positioned(
                right: _polygonRight!,
                top: _polygonTop!,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // 제스처 시작 시 현재 크기를 기록해 배율 계산의 기준으로 삼는다
                  onScaleStart: (_) => _polygonScaleStart = _polygonSize,
                  // onScaleUpdate 하나로 드래그(1손가락)와 핀치(2손가락)를 모두 처리한다
                  // - focalPointDelta: 초점(손가락 중심) 이동량 → 패널 위치 갱신
                  // - scale: 시작 시점 대비 배율 → 두 손가락일 때만 크기 반영
                  onScaleUpdate: (details) {
                    setState(() {
                      // 두 손가락 핀치: 배율로 크기 조정 (경계 clamp 에 새 크기 사용하므로 먼저 처리)
                      if (details.pointerCount >= 2) {
                        _polygonSize = (_polygonScaleStart * details.scale)
                            .clamp(48.0, kMax);
                      }
                      // 드래그: right 는 이동 방향과 반대로 변한다 (오른쪽 이동 → right 감소)
                      _polygonRight = (_polygonRight! - details.focalPointDelta.dx)
                          .clamp(0.0, q.size.width - _polygonSize);
                      _polygonTop = (_polygonTop! + details.focalPointDelta.dy)
                          .clamp(q.padding.top, q.size.height - _polygonSize - 80);
                    });
                  },
                  // 탭: 크기만 바꾼다. Positioned.right 가 고정되어 있으므로
                  // AnimatedContainer 너비가 커질수록 패널이 자동으로 왼쪽으로 확장됨.
                  // 힌트 표시 중 탭하면 힌트를 즉시 닫고 패널을 축소한다.
                  // 확장 시 화면 왼쪽으로 벗어나지 않도록 현재 right 위치를 기준으로 상한을 결정한다.
                  onTap: () {
                    setState(() {
                      if (_polygonHintVisible) {
                        _polygonHintVisible = false;
                        _polygonSize = 48.0;
                      } else if (_polygonSize > 80) {
                        _polygonSize = 48.0;
                      } else {
                        // 현재 위치에서 화면 왼쪽 끝까지의 공간 = screenWidth - right
                        final maxFit = q.size.width - _polygonRight!;
                        _polygonSize = maxFit.clamp(48.0, kMax);
                      }
                    });
                  },
                  child: _PolygonPreviewButton(
                    imageUrl: widget.polygonImageUrl!,
                    size: _polygonSize,
                    // 진입 2초간 패널 하단에 안내 문구 표시
                    hintText: _polygonHintVisible
                        ? '제공된 폴리곤을 따라\n경로를 그려주세요'
                        : null,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('코스 이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '코스 이름 입력'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(courseEditorProvider.notifier).setCourseName(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showSearchSheet(CourseEditorNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SearchSheet(notifier: notifier),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 상단 타이틀 바
// 뒤로 가기 버튼 · 편집 가능한 코스 이름 · 저장 상태 표시
// 폴리곤 버튼은 별도 Positioned 로 분리됨
// ─────────────────────────────────────────────────────────────────────
class _TitleBar extends StatelessWidget {
  final CourseEditorState state;
  final VoidCallback onNameTap;

  const _TitleBar({required this.state, required this.onNameTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // 뒤로 가기 버튼
          IconButton(
            icon: const Icon(Icons.arrow_back),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),

          // 탭하면 이름 수정 다이얼로그가 열리는 코스 이름 영역
          Expanded(
            child: GestureDetector(
              onTap: onNameTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      state.courseName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 저장 진행 중이면 스피너, 완료 노드가 있으면 체크 아이콘
          if (state.isSaving)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (state.nodes.isNotEmpty)
            const Icon(Icons.check_circle_outline, size: 16, color: Colors.green)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 오른쪽 플로팅 버튼 열
// 검색 · 현재 위치 이동 · 자동 경로 스냅 토글
// ─────────────────────────────────────────────────────────────────────
class _RightFabColumn extends StatelessWidget {
  final CourseEditorNotifier notifier;

  // 검색 버튼 탭 시 바텀 시트를 여는 콜백 (부모에서 context 사용)
  final VoidCallback onSearchTap;

  const _RightFabColumn({
    required this.notifier,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 장소 검색 버튼 → 바텀 시트로 좌표 입력 후 카메라 이동
        _FabIconButton(
          icon: Icons.search,
          tooltip: '장소 검색',
          onTap: onSearchTap,
        ),
        const SizedBox(height: 8),

        // 현재 GPS 위치로 지도 카메라를 이동
        _FabIconButton(
          icon: Icons.my_location,
          tooltip: '현재 위치',
          onTap: notifier.centerOnCurrentLocation,
        ),
      ],
    );
  }
}

// 오른쪽 열에서 재사용하는 원형 플로팅 아이콘 버튼
class _FabIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _FabIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            // 활성화 상태면 경로 색상, 비활성이면 흰색 배경
            color: isActive ? kCourseRouteColor : Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: isActive ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 하단 컨트롤 패널
// 왼쪽: 실행취소 · 다시실행 · 초기화 버튼
// 가운데: 총 거리 뱃지
// 오른쪽: 저장(CTA) 버튼
// ─────────────────────────────────────────────────────────────────────
class _BottomPanel extends StatelessWidget {
  final CourseEditorState state;
  final CourseEditorNotifier notifier;
  final VoidCallback onSave;

  const _BottomPanel({
    required this.state,
    required this.notifier,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final hasNodes = state.nodes.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ControlButton(
            icon: Icons.undo_rounded,
            label: '취소',
            enabled: state.undoStack.isNotEmpty,
            onTap: notifier.undo,
          ),
          const SizedBox(width: 8),
          _ControlButton(
            icon: Icons.redo_rounded,
            label: '복원',
            enabled: state.redoStack.isNotEmpty,
            onTap: notifier.redo,
          ),
          const SizedBox(width: 8),
          _ControlButton(
            icon: Icons.delete_outline_rounded,
            label: '초기화',
            enabled: hasNodes,
            onTap: notifier.reset,
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (hasNodes && !state.isSaving) ? onSave : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kCourseRouteColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: state.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '저장',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// 하단 패널 소형 컨트롤 버튼 — 둥근 사각 배경에 아이콘 + 라벨
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled ? Colors.black87 : Colors.grey.shade400;
    final labelColor = enabled ? Colors.black54 : Colors.grey.shade400;
    final bgColor = enabled ? Colors.grey.shade100 : Colors.grey.shade50;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: labelColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 총 거리 표시 뱃지
class _KmBadge extends StatelessWidget {
  final double km;

  const _KmBadge({required this.km});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1AFF5722), // kCourseRouteColor 10% opacity
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.straighten_rounded, size: 13, color: kCourseRouteColor),
          const SizedBox(width: 4),
          Text(
            '${km.toStringAsFixed(2)} km',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kCourseRouteColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 도로 상태 안내 힌트 배너
// hasWays 에 따라 "확대하세요" 또는 "도로를 탭하세요" 메시지를 표시한다
// 노드가 하나라도 추가되면 부모에서 숨겨진다
// ─────────────────────────────────────────────────────────────────────
class _RoadHintBanner extends StatelessWidget {
  final bool hasWays;

  const _RoadHintBanner({required this.hasWays});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text, Color color) = hasWays
        ? (
            Icons.touch_app,
            '파란 도로 위를 탭해 경로를 추가하세요',
            const Color(0xFF1976D2), // 도로 오버레이와 유사한 파랑
          )
        : (
            Icons.zoom_in,
            '지도를 더 확대하면 달릴 수 있는 도로가 표시됩니다',
            Colors.black54,
          );

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 경로 다각형 미리보기 버튼
// 노드가 없으면 회색 아이콘을 표시하고, 있으면 실제 경로를 축소해서 그린다.
// 탭하면 Dialog 에서 확대된 경로 모양을 보여준다.
// ─────────────────────────────────────────────────────────────────────
// 폴리곤 미리보기 패널 — 순수 표시 위젯
//
// 크기(size)만 받아 AnimatedContainer 로 부드럽게 전환한다.
// 탭·드래그 이벤트는 부모 GestureDetector 가 전담하므로 이 위젯에 콜백 없음.
// size > 80 이면 확대 상태로 간주해 × 아이콘을 우상단에 표시한다.
class _PolygonPreviewButton extends StatelessWidget {
  final String imageUrl;
  // 현재 패널 크기(px). 48 = 축소 버튼 상태
  final double size;
  // null 이 아니면 패널 하단에 반투명 안내 문구를 오버레이로 표시
  final String? hintText;

  const _PolygonPreviewButton({
    required this.imageUrl,
    required this.size,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final bool isExpanded = size > 80;
    final double radius = isExpanded ? 12 : 8;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kCourseRouteColor, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.broken_image_outlined,
                color: Colors.grey.shade500,
                size: isExpanded ? 40 : 20,
              ),
            ),
            // 확대 상태: 탭으로 닫을 수 있음을 × 아이콘으로 안내
            if (isExpanded)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            // 힌트 문구 — 진입 2초간 패널 하단에 반투명 배경으로 표시
            if (isExpanded && hintText != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.5)),
                  ),
                  child: Text(
                    hintText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Pretendard',
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 장소 검색 결과 모델
// ─────────────────────────────────────────────────────────────────────
class _PlaceResult {
  final String title;
  final String address;
  final double lat;
  final double lng;

  const _PlaceResult({
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

// ─────────────────────────────────────────────────────────────────────
// 장소 검색 바텀 시트
// 네이버 지역 검색 API 로 장소명·주소를 검색해 지도를 해당 위치로 이동시킨다
// .env: NAVER_SEARCH_CLIENT_ID / NAVER_SEARCH_CLIENT_SECRET 필요
// ─────────────────────────────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final CourseEditorNotifier notifier;

  const _SearchSheet({required this.notifier});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();
  List<_PlaceResult> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final response = await Dio().get(
        'https://openapi.naver.com/v1/search/local.json',
        queryParameters: {'query': query, 'display': 10},
        options: Options(headers: {
          'X-Naver-Client-Id': dotenv.env['NAVER_SEARCH_CLIENT_ID'] ?? '',
          'X-Naver-Client-Secret': dotenv.env['NAVER_SEARCH_CLIENT_SECRET'] ?? '',
        }),
      );

      final items = response.data['items'] as List;
      final results = items.map((item) {
        // 네이버 지역 검색 API: WGS84 × 10^7 정수 문자열
        // 예) mapx="1270276000" → 127.0276, mapy="374979000" → 37.4979
        final lat = double.parse(item['mapy'] as String) / 1e7;
        final lng = double.parse(item['mapx'] as String) / 1e7;
        final title = (item['title'] as String).replaceAll(RegExp(r'<[^>]*>'), '');
        final address = (item['roadAddress'] as String? ?? '').isNotEmpty
            ? item['roadAddress'] as String
            : item['address'] as String? ?? '';
        return _PlaceResult(title: title, address: address, lat: lat, lng: lng);
      }).toList();

      setState(() {
        _results = results;
        if (_results.isEmpty) _error = '검색 결과가 없습니다';
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final msg = status == 401
          ? 'API 인증 오류 (키를 확인해 주세요)'
          : status == 403
              ? 'API 권한 없음 (지역 검색 API가 활성화되어 있는지 확인해 주세요)'
              : '검색 실패 (${status ?? '네트워크 오류'})';
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = '오류: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '장소 검색',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '장소 또는 주소를 입력하세요',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
            ),
            onSubmitted: (_) => _search(),
          ),

          if (_loading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
          ] else if (_error != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_results.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = _results[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: const Icon(Icons.place_outlined, color: kCourseRouteColor),
                    title: Text(
                      r.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: r.address.isNotEmpty
                        ? Text(
                            r.address,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        : null,
                    onTap: () {
                      final target = NLatLng(r.lat, r.lng);
                      Navigator.pop(context);
                      widget.notifier.moveCameraTo(target);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

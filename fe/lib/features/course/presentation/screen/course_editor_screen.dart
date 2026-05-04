import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/presentation/course_editor_viewmodel.dart';
import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/widgets/course_editor_map_view.dart';

// 코스 생성 편집 화면
// Scaffold > Stack 구조로 전체화면 지도 위에 UI 레이어를 겹쳐 쌓는다
class CourseEditorScreen extends ConsumerWidget {
  const CourseEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // state 변경 시 화면 전체가 다시 빌드된다
    final state = ref.watch(courseEditorProvider);
    final notifier = ref.read(courseEditorProvider.notifier);

    // isSaving 이 true → false 로 바뀌는 순간을 감지해
    // 저장 성공이면 화면을 닫고, 실패면 스낵바를 표시한다
    ref.listen<CourseEditorState>(courseEditorProvider, (prev, next) {
      if (prev?.isSaving == true && !next.isSaving) {
        // 비동기 저장이 완료되는 시점에 위젯이 이미 트리에서 제거됐을 수 있기때문에
        // context 가 유효하지 않은 상태에서 Navigator/ScaffoldMessenger 를
        // 호출하면 런타임 예외가 발생하므로 mounted 여부를 먼저 확인
        if (!context.mounted) return;
        if (next.saveError == null) {
          // 저장 성공 → 편집 화면을 닫는다
          Navigator.of(context).pop();
        } else {
          // 저장 실패 → 오류 메시지를 스낵바로 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.saveError!)),
          );
        }
      }
    });

    return Scaffold(
      // 키보드가 올라와도 지도 영역이 밀리지 않도록 false 설정
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1단계: 전체화면 지도 (가장 아래 레이어)
          // 지도를 탭하면 CourseEditorMapView 가 notifier.addNode 를 호출한다
          const Positioned.fill(
            child: CourseEditorMapView(),
          ),

          // 2단계: 상단 정보 바 (코스명·거리·저장 상태)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _TopInfoBar(
                state: state,
                onNameTap: () => _showNameDialog(context, ref, state.courseName),
              ),
            ),
          ),

          // 3단계: 오른쪽 플로팅 버튼 열 (검색·현재위치·자동경로)
          // bottom: 120 으로 하단 패널과 겹치지 않도록 여백 확보
          Positioned(
            right: 12,
            bottom: 120,
            child: _RightFabColumn(
              state: state,
              notifier: notifier,
              onSearchTap: () => _showSearchSheet(context, notifier),
            ),
          ),

          // 4단계: 하단 컨트롤 패널 (실행취소·다시실행·초기화 + 저장 CTA)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(state: state, notifier: notifier),
          ),
        ],
      ),
    );
  }

  // 코스 이름 수정 다이얼로그를 표시한다
  void _showNameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) {
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

  // 장소 이동 바텀 시트를 표시한다
  void _showSearchSheet(
    BuildContext context,
    CourseEditorNotifier notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      // isScrollControlled: 키보드가 올라와도 시트가 올라올 수 있도록 허용
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SearchSheet(notifier: notifier),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 상단 정보 바
// 뒤로 가기 버튼 · 편집 가능한 코스 이름 · 총 거리 · 저장 상태 표시
// ─────────────────────────────────────────────────────────────────────
class _TopInfoBar extends StatelessWidget {
  final CourseEditorState state;

  // 코스 이름 영역을 탭했을 때 이름 수정 다이얼로그를 여는 콜백
  final VoidCallback onNameTap;

  const _TopInfoBar({required this.state, required this.onNameTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.93),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 뒤로 가기 버튼 (AppBar 가 없으므로 직접 구현)
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
                  // 이름을 수정할 수 있음을 나타내는 작은 편집 아이콘
                  const Icon(Icons.edit, size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 저장 진행 중일 때 로딩 스피너, 아닐 때는 저장 완료 아이콘
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
          const SizedBox(width: 8),

          // 실시간 총 거리 (노드가 늘어날 때마다 자동 갱신)
          Text(
            '${state.totalDistanceKm.toStringAsFixed(2)} km',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              // 경로 폴리라인 색상과 동일하게 통일
              color: kCourseRouteColor,
            ),
          ),
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
  final CourseEditorState state;
  final CourseEditorNotifier notifier;

  // 검색 버튼 탭 시 바텀 시트를 여는 콜백 (부모에서 context 사용)
  final VoidCallback onSearchTap;

  const _RightFabColumn({
    required this.state,
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
        const SizedBox(height: 8),

        // 자동 경로 스냅 토글 (활성화 시 버튼 색상 강조)
        _FabIconButton(
          icon: Icons.alt_route,
          tooltip: '자동 경로',
          isActive: state.autoSnap,
          onTap: notifier.toggleAutoSnap,
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
// 오른쪽: 저장(CTA) 버튼
// ─────────────────────────────────────────────────────────────────────
class _BottomPanel extends StatelessWidget {
  final CourseEditorState state;
  final CourseEditorNotifier notifier;

  const _BottomPanel({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final hasNodes = state.nodes.isNotEmpty;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        // SafeArea 하단(홈 인디케이터) 여백만큼 추가 패딩
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        children: [
          // 실행취소 버튼 (undoStack 이 비어있으면 비활성)
          _ControlButton(
            icon: Icons.undo,
            label: '취소',
            enabled: state.undoStack.isNotEmpty,
            onTap: notifier.undo,
          ),
          const SizedBox(width: 8),

          // 다시실행 버튼 (redoStack 이 비어있으면 비활성)
          _ControlButton(
            icon: Icons.redo,
            label: '복원',
            enabled: state.redoStack.isNotEmpty,
            onTap: notifier.redo,
          ),
          const SizedBox(width: 8),

          // 전체 초기화 버튼 (노드가 없으면 비활성)
          _ControlButton(
            icon: Icons.delete_outline,
            label: '초기화',
            enabled: hasNodes,
            onTap: notifier.reset,
          ),
          const Spacer(),

          // 저장 CTA 버튼
          // · 노드가 없거나 저장 중이면 비활성
          // · 저장 완료 or 실패는 ref.listen 이 처리 (screen 레벨)
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: (hasNodes && !state.isSaving)
                  ? notifier.saveCourse
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kCourseRouteColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// 하단 패널의 소형 컨트롤 버튼 (아이콘 + 라벨 텍스트)
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
    // 비활성 상태면 회색, 활성이면 어두운 색상으로 표시
    final color = enabled ? Colors.black87 : Colors.grey.shade400;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 장소 검색 바텀 시트
// "위도, 경도" 형식으로 입력하면 해당 좌표로 지도를 이동시킨다
// ─────────────────────────────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final CourseEditorNotifier notifier;

  const _SearchSheet({required this.notifier});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();

  // 잘못된 입력 시 TextField 아래에 표시할 오류 메시지
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // "위도, 경도" 형식을 파싱해 카메라를 해당 좌표로 이동시킨다
  void _onSearch() {
    final input = _controller.text.trim();
    final parts = input.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        widget.notifier.moveCameraTo(NLatLng(lat, lng));
        Navigator.pop(context);
        return;
      }
    }
    // 형식이 맞지 않으면 오류 메시지를 표시하고 시트를 닫지 않는다
    setState(
      () => _errorText = '올바른 형식: 위도, 경도  (예: 37.5665, 126.9780)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // viewInsets.bottom: 키보드 높이만큼 패딩을 줘서 TextField 가 가려지지 않도록
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 시트 제목
          const Text(
            '장소 이동',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 좌표 입력 필드
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '위도, 경도  (예: 37.5665, 126.9780)',
              errorText: _errorText,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _onSearch,
              ),
            ),
            // 키보드 완료 버튼으로도 검색할 수 있다
            onSubmitted: (_) => _onSearch(),
          ),
          const SizedBox(height: 8),

          // 사용 안내 텍스트
          const Text(
            '지도에서 직접 탭하거나 좌표를 입력해 위치로 이동',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

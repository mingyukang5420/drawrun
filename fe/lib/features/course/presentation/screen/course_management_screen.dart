import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/presentation/course_management_viewmodel.dart';
import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/screen/course_detail_screen.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';
import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/screen/running_countdown_screen.dart';
import 'package:running/shared/network/api_exception.dart';

// 챌린지 내 코스 관리 화면
// 쉬움/어려움 탭으로 분리, 완료/미시작 상태를 카드 스타일로 구분
class CourseManagementScreen extends ConsumerStatefulWidget {
  // 러닝 세션 시작 시 setSessionContext 에 전달할 챌린지 ID
  final int? challengeId;

  const CourseManagementScreen({super.key, this.challengeId});

  @override
  ConsumerState<CourseManagementScreen> createState() =>
      _CourseManagementScreenState();
}

class _CourseManagementScreenState
    extends ConsumerState<CourseManagementScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 열리면 챌린지 코스 목록을 불러온다
    Future.microtask(
      () => ref.read(courseManagementProvider.notifier).loadMyCourses(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseManagementProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 — 챌린지 제목을 부제목으로 표시
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '내 챌린지 코스',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (state.challengeTitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      state.challengeTitle!,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 쉬움 / 어려움 난이도 탭 (전체 탭 없음 — 탭 재선택 시 전체로 토글됨)
            _DifficultyTabs(
              selected: state.selectedDifficulty,
              onSelect: (d) =>
                  ref.read(courseManagementProvider.notifier).selectDifficulty(d),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _CourseList(
                state: state,
                ref: ref,
                challengeId: widget.challengeId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 난이도 탭 ──────────────────────────────────────────────────────────
// 전체 탭 없음 — 선택된 탭을 다시 누르면 전체 보기로 토글
class _DifficultyTabs extends StatelessWidget {
  final String? selected; // null=전체(토글), 'EASY', 'HARD'
  final ValueChanged<String> onSelect;

  const _DifficultyTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _Tab(
            label: '쉬움',
            color: const Color(0xFF27AE60),
            isSelected: selected == 'EASY',
            onTap: () => onSelect('EASY'),
          ),
          const SizedBox(width: 8),
          _Tab(
            label: '어려움',
            color: const Color(0xFFE74C3C),
            isSelected: selected == 'HARD',
            onTap: () => onSelect('HARD'),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ── 코스 목록 ─────────────────────────────────────────────────────────
class _CourseList extends StatelessWidget {
  final CourseManagementState state;
  final WidgetRef ref;
  final int? challengeId;

  const _CourseList({
    required this.state,
    required this.ref,
    this.challengeId,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(state.errorMessage!,
                style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(courseManagementProvider.notifier).loadMyCourses(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final drafts = state.filtered;

    if (drafts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 56, color: Color(0xFFD1D5DB)),
            SizedBox(height: 12),
            Text(
              '해당 난이도의 코스가 없습니다',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    // 완료된 코스를 위로, 미시작 코스를 아래로 정렬
    final sorted = [...drafts]..sort((a, b) {
        final aScore = _statusOrder(a.status);
        final bScore = _statusOrder(b.status);
        return aScore.compareTo(bScore);
      });

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(courseManagementProvider.notifier).loadMyCourses(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _CourseDraftCard(
          draft: sorted[i],
          challengeId: challengeId,
          onDelete: () => _confirmDelete(context, ref, sorted[i].courseDraftId),
        ),
      ),
    );
  }

  // 완료(0) → 등록(1) → 미시작(2) 순서로 정렬
  int _statusOrder(String? status) => switch (status) {
        'DONE' => 0,
        'REGISTERED' => 1,
        _ => 2,
      };
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, int courseDraftId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('코스 삭제'),
      content: const Text('이 코스를 삭제하면 되돌릴 수 없습니다.\n정말 삭제하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFE74C3C)),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    try {
      await ref
          .read(courseManagementProvider.notifier)
          .deleteCourse(courseDraftId);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('삭제에 실패했습니다')));
      }
    }
  }
}

// ── 코스 카드 ─────────────────────────────────────────────────────────
// 왼쪽 난이도 색상 바 + 완료/미시작 상태를 시각적으로 구분
class _CourseDraftCard extends ConsumerWidget {
  final CourseDraft draft;
  final VoidCallback onDelete;
  final int? challengeId;

  const _CourseDraftCard({
    required this.draft,
    required this.onDelete,
    this.challengeId,
  });

  static const _difficultyColor = {
    'EASY': Color(0xFF27AE60),
    'HARD': Color(0xFFE74C3C),
    'NORMAL': Color(0xFFE67E22),
  };
  static const _difficultyLabel = {
    'EASY': '쉬움',
    'HARD': '어려움',
    'NORMAL': '보통',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 카드 색상/라벨은 챌린지 자체 난이도(challengeDifficulty) 기준
    // difficulty 는 에디터 코스 난이도로 별개 개념
    final diffColor =
        _difficultyColor[draft.challengeDifficulty?.toUpperCase()] ??
            const Color(0xFF6B7280);
    final diffLabel =
        _difficultyLabel[draft.challengeDifficulty?.toUpperCase()] ?? '';

    // 러닝을 완료한 코스 여부
    final isCompleted =
        draft.status == 'DONE' || draft.status == 'REGISTERED';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        // 카드 탭 → 상세 화면
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                CourseDetailScreen(courseDraftId: draft.courseDraftId),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 왼쪽 난이도 색상 바 (완료=진한색, 미시작=연한색)
            Container(
              width: 5,
              color: isCompleted
                  ? diffColor
                  : diffColor.withValues(alpha: 0.3),
            ),

            // 썸네일
            _Thumbnail(url: draft.trackImageUrl, isCompleted: isCompleted),

            // 정보 영역
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목 + 난이도 배지 + 상태 배지
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            draft.title,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isCompleted
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 완료 여부 배지
                        _StatusBadge(isCompleted: isCompleted),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 거리 + 난이도 라벨
                    Row(
                      children: [
                        const Icon(Icons.straighten,
                            size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 3),
                        Text(
                          '${draft.distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        if (diffLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: diffColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              diffLabel,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: diffColor,
                              ),
                            ),
                          ),
                        ],
                        // 완료 시 유사도 점수 표시
                        if (isCompleted &&
                            draft.similarityScore != null) ...[
                          const Spacer(),
                          Text(
                            '유사도 ${draft.similarityScore!.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: diffColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 버튼 행
                    Row(
                      children: [
                        // 편집 버튼 (미시작만 표시)
                        if (!isCompleted) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CourseEditorScreen()),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('편집'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6B7280),
                                side: const BorderSide(
                                    color: Color(0xFFE5E7EB)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                textStyle: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // 러닝 시작 / 다시 도전 버튼
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // courseId 있으면 완성된 코스 러닝, 없으면 에디터 검증 러닝
                              ref
                                  .read(runningViewModelProvider.notifier)
                                  .setSessionContext(
                                    challengeId: challengeId,
                                    courseId: draft.courseId,
                                    courseDraftId: draft.courseId == null
                                        ? draft.courseDraftId
                                        : null,
                                  );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const RunningCountdownScreen()),
                              );
                            },
                            icon: Icon(
                              isCompleted
                                  ? Icons.refresh
                                  : Icons.play_arrow,
                              size: 14,
                            ),
                            label: Text(isCompleted ? '다시 도전' : '러닝 시작'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: diffColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              textStyle: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 삭제 버튼
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: onDelete,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE74C3C),
                              side:
                                  const BorderSide(color: Color(0xFFE74C3C)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child:
                                const Icon(Icons.delete_outline, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 완료/미시작 상태 배지 ─────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool isCompleted;

  const _StatusBadge({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : const Color(0xFF9CA3AF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 10,
            color: isCompleted
                ? const Color(0xFF10B981)
                : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 3),
          Text(
            isCompleted ? '완료' : '시작 전',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isCompleted
                  ? const Color(0xFF10B981)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 썸네일 ────────────────────────────────────────────────────────────
class _Thumbnail extends StatelessWidget {
  final String? url;
  // 미시작 코스는 썸네일을 흐리게 표시
  final bool isCompleted;

  const _Thumbnail({this.url, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final img = url != null
        ? Image.network(
            url!,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(),
          )
        : _placeholder();

    // 미시작 코스는 썸네일에 반투명 오버레이를 덮어 흐리게 처리
    if (!isCompleted) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: 0.5),
          BlendMode.srcOver,
        ),
        child: SizedBox(width: 80, height: 80, child: img),
      );
    }
    return SizedBox(width: 80, height: 80, child: img);
  }

  Widget _placeholder() => Container(
        width: 80,
        height: 80,
        color: const Color(0xFFE5E7EB),
        child: const Icon(Icons.landscape, color: Color(0xFFD1D5DB), size: 32),
      );
}

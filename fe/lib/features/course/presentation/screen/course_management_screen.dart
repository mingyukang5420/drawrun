import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/presentation/course_management_viewmodel.dart';
import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/screen/course_detail_screen.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';
import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/screen/running_countdown_screen.dart';

// 챌린지 내 코스 관리 화면
// 랭킹 화면과 동일한 DefaultTabController + TabBar 패턴으로 Easy/Hard 탭 전환
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

  static const _easyColor = Color(0xFF27AE60);
  static const _hardColor = Color(0xFFE74C3C);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseManagementProvider);

    final easyDrafts = state.byDifficulty('EASY');
    final hardDrafts = state.byDifficulty('HARD');

    // DefaultTabController 로 TabBar ↔ TabBarView 를 자동 연결
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            '내 챌린지 코스 관리',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          // 랭킹 화면과 동일한 탭 바 스타일
          bottom: const TabBar(
            labelColor: Color(0xFF1C1C1E),
            unselectedLabelColor: Color(0xFF9CA3AF),
            labelStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            indicatorColor: Color(0xFF1C1C1E),
            indicatorWeight: 2.5,
            tabs: [Tab(text: 'Easy'), Tab(text: 'Hard')],
          ),
        ),
        body: _buildBody(state, easyDrafts, hardDrafts),
      ),
    );
  }

  Widget _buildBody(
    CourseManagementState state,
    List<CourseDraft> easyDrafts,
    List<CourseDraft> hardDrafts,
  ) {
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

    // 각 탭에 난이도 색상을 전달해 필터 칩 색상이 탭과 일치하도록 한다
    return TabBarView(
      children: [
        _CourseListContent(
          drafts: easyDrafts,
          difficultyColor: _easyColor,
          ref: ref,
          challengeId: widget.challengeId,
        ),
        _CourseListContent(
          drafts: hardDrafts,
          difficultyColor: _hardColor,
          ref: ref,
          challengeId: widget.challengeId,
        ),
      ],
    );
  }
}

// ── 탭별 코스 목록 (전체 / 진행 중 / 완료 필터 포함) ─────────────────────
class _CourseListContent extends StatefulWidget {
  final List<CourseDraft> drafts;
  // 선택된 필터 칩 색상을 탭 난이도 색상과 맞춘다
  final Color difficultyColor;
  final WidgetRef ref;
  final int? challengeId;

  const _CourseListContent({
    required this.drafts,
    required this.difficultyColor,
    required this.ref,
    this.challengeId,
  });

  @override
  State<_CourseListContent> createState() => _CourseListContentState();
}

class _CourseListContentState extends State<_CourseListContent> {
  // 현재 선택된 필터: 'all' | 'progress' | 'done'
  String _filter = 'all';

  // 선택된 필터에 따라 코스 목록을 걸러낸다
  List<CourseDraft> get _filtered {
    switch (_filter) {
      case 'progress':
        // 아직 러닝을 완료하지 않은 코스
        return widget.drafts
            .where((d) => d.status != 'DONE' && d.status != 'REGISTERED')
            .toList();
      case 'done':
        // 러닝을 완료한 코스
        return widget.drafts
            .where((d) => d.status == 'DONE' || d.status == 'REGISTERED')
            .toList();
      default:
        // 전체: 완료된 코스를 위로 정렬
        return [...widget.drafts]..sort(
            (a, b) => _statusOrder(a.status).compareTo(_statusOrder(b.status)),
          );
    }
  }

  // 완료(0) → 등록(1) → 미시작(2) 순서로 정렬
  int _statusOrder(String? status) => switch (status) {
        'DONE' => 0,
        'REGISTERED' => 1,
        _ => 2,
      };

  // 각 필터별 코스 수를 미리 계산해 칩에 표시
  int get _allCount => widget.drafts.length;
  int get _progressCount => widget.drafts
      .where((d) => d.status != 'DONE' && d.status != 'REGISTERED')
      .length;
  int get _doneCount => widget.drafts
      .where((d) => d.status == 'DONE' || d.status == 'REGISTERED')
      .length;

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final color = widget.difficultyColor;

    return Column(
      children: [
        // 상태 필터 버튼 행 — 각 칩에 해당 조건의 코스 수 표시
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              _FilterChip(
                label: '전체',
                count: _allCount,
                selected: _filter == 'all',
                selectedColor: color,
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '진행 중',
                count: _progressCount,
                selected: _filter == 'progress',
                selectedColor: color,
                onTap: () => setState(() => _filter = 'progress'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '완료',
                count: _doneCount,
                selected: _filter == 'done',
                selectedColor: color,
                onTap: () => setState(() => _filter = 'done'),
              ),
            ],
          ),
        ),

        // 완료 필터 선택 시 — 완료 수와 평균 유사도 요약
        if (_filter == 'done' && _doneCount > 0)
          _CompletedSummary(
            completedDrafts: items,
            color: color,
          ),

        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),

        // 코스 목록
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route_outlined,
                          size: 56, color: Color(0xFFD1D5DB)),
                      const SizedBox(height: 12),
                      Text(
                        widget.drafts.isEmpty
                            ? '해당 난이도의 코스가 없습니다'
                            : '해당 조건의 코스가 없습니다',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => widget.ref
                      .read(courseManagementProvider.notifier)
                      .loadMyCourses(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _CourseDraftCard(
                      draft: items[i],
                      challengeId: widget.challengeId,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── 완료 탭 요약 행 ───────────────────────────────────────────────────
// 완료 필터 선택 시 상단에 완료 개수 + 평균 유사도를 한 줄로 표시
class _CompletedSummary extends StatelessWidget {
  final List<CourseDraft> completedDrafts;
  final Color color;

  const _CompletedSummary({
    required this.completedDrafts,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 유사도 점수가 있는 항목만 평균 계산
    final scores = completedDrafts
        .where((d) => d.similarityScore != null)
        .map((d) => d.similarityScore!)
        .toList();
    final avgScore =
        scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '${completedDrafts.length}개 완료',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (avgScore != null) ...[
            const SizedBox(width: 12),
            Text(
              '평균 유사도 ${avgScore.toStringAsFixed(0)}%',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 상태 필터 칩 버튼 ─────────────────────────────────────────────────
// 선택 시 selectedColor 로 채워지고, 코스 수(count)를 라벨 옆에 표시
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 4),
            // 해당 조건의 코스 수
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 코스 카드 ─────────────────────────────────────────────────────────
// 왼쪽 난이도 색상 바 + 완료/미시작 상태를 시각적으로 구분
class _CourseDraftCard extends ConsumerWidget {
  final CourseDraft draft;
  final int? challengeId;

  const _CourseDraftCard({
    required this.draft,
    this.challengeId,
  });

  static const _difficultyColor = {
    'EASY': Color(0xFF27AE60),
    'HARD': Color(0xFFE74C3C),
    'NORMAL': Color(0xFFE67E22),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 카드 색상/라벨은 챌린지 자체 난이도(challengeDifficulty) 기준
    // difficulty 는 에디터 코스 난이도로 별개 개념
    final diffColor =
        _difficultyColor[draft.challengeDifficulty?.toUpperCase()] ??
            const Color(0xFF6B7280);
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
        child: IntrinsicHeight(
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
                      // 제목 + 상태 배지
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
            errorBuilder: (_, __, ___) => _placeholder(),
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

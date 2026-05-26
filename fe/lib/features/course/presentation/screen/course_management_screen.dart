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
// 상위 탭: 도전중 / 도전완료 (status 기준)
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
    Future.microtask(
      () => ref.read(courseManagementProvider.notifier).loadMyCourses(),
    );
  }

  // 도전중 탭 기준색 — 중립 회색
  static const _progressColor = Color(0xFF6B7280);
  // 도전완료 탭 기준색 — 성공 초록
  static const _doneColor = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseManagementProvider);

    // 상위 탭 기준: status 로 분리
    final progressDrafts = state.drafts
        .where((d) => d.status != 'DONE' && d.status != 'REGISTERED')
        .toList();
    final doneDrafts = state.drafts
        .where((d) => d.status == 'DONE' || d.status == 'REGISTERED')
        .toList();

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
            tabs: [Tab(text: '도전중'), Tab(text: '도전완료')],
          ),
        ),
        body: _buildBody(state, progressDrafts, doneDrafts),
      ),
    );
  }

  Widget _buildBody(
    CourseManagementState state,
    List<CourseDraft> progressDrafts,
    List<CourseDraft> doneDrafts,
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

    return TabBarView(
      children: [
        // 도전중 탭 — status READY 코스 목록
        _CourseListContent(
          drafts: progressDrafts,
          emptyMessage: '도전 중인 코스가 없습니다',
          showSummary: false,
          summaryColor: _progressColor,
          ref: ref,
          challengeId: widget.challengeId,
        ),
        // 도전완료 탭 — status DONE / REGISTERED 코스 목록 + 요약 배너
        _CourseListContent(
          drafts: doneDrafts,
          emptyMessage: '완료한 코스가 없습니다',
          showSummary: true,
          summaryColor: _doneColor,
          ref: ref,
          challengeId: widget.challengeId,
        ),
      ],
    );
  }
}

// ── 탭별 코스 목록 ─────────────────────────────────────────────────────
// 탭이 이미 status 로 분리되어 있으므로 내부 필터 없이 전달받은 drafts 를 그대로 표시.
// 도전완료 탭에서만 showSummary=true 로 상단 요약 배너를 표시한다.
class _CourseListContent extends StatelessWidget {
  final List<CourseDraft> drafts;
  final String emptyMessage;
  final bool showSummary;
  final Color summaryColor;
  final WidgetRef ref;
  final int? challengeId;

  const _CourseListContent({
    required this.drafts,
    required this.emptyMessage,
    required this.showSummary,
    required this.summaryColor,
    required this.ref,
    this.challengeId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 도전완료 탭에서만 완료 수 + 평균 유사도 요약 표시
        if (showSummary && drafts.isNotEmpty)
          _CompletedSummary(completedDrafts: drafts, color: summaryColor),

        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),

        Expanded(
          child: drafts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route_outlined,
                          size: 56, color: Color(0xFFD1D5DB)),
                      const SizedBox(height: 12),
                      Text(
                        emptyMessage,
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
                  onRefresh: () => ref
                      .read(courseManagementProvider.notifier)
                      .loadMyCourses(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: drafts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _CourseDraftCard(
                      draft: drafts[i],
                      challengeId: challengeId,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── 도전완료 탭 요약 배너 ─────────────────────────────────────────────
// 완료 개수 + 평균 유사도를 한 줄로 표시
class _CompletedSummary extends StatelessWidget {
  final List<CourseDraft> completedDrafts;
  final Color color;

  const _CompletedSummary({
    required this.completedDrafts,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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

// ── 코스 카드 ─────────────────────────────────────────────────────────
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
    final diffColor =
        _difficultyColor[draft.challengeDifficulty?.toUpperCase()] ??
            const Color(0xFF6B7280);
    final isCompleted =
        draft.status == 'DONE' || draft.status == 'REGISTERED';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(
              courseDraftId: draft.courseDraftId,
              draft: draft,
            ),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 썸네일 (탭으로 status 를 이미 구분하므로 흐림 없이 그대로 표시)
              _Thumbnail(url: draft.trackImageUrl),

              // 정보 영역
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 난이도 배지 (좌측 상단)
                      if (draft.challengeDifficulty != null)
                        _DifficultyBadge(
                          difficulty: draft.challengeDifficulty!,
                          color: diffColor,
                        ),
                      if (draft.challengeDifficulty != null)
                        const SizedBox(height: 4),
                      // 제목
                      Text(
                        draft.title,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF1C1C1E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // 거리 + 유사도
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
                          if (isCompleted && draft.similarityScore != null) ...[
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
                                    builder: (_) => CourseEditorScreen(
                                      challengeId: draft.challengeId,
                                      courseDraftId: draft.courseDraftId,
                                    ),
                                  ),
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
                                ref
                                    .read(runningViewModelProvider.notifier)
                                    .setSessionContext(
                                      challengeId: draft.challengeId,
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

// ── 난이도 배지 ───────────────────────────────────────────────────────
class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  final Color color;

  const _DifficultyBadge({required this.difficulty, required this.color});

  String get _label {
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        return 'EASY';
      case 'HARD':
        return 'HARD';
      default:
        return difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── 썸네일 ────────────────────────────────────────────────────────────
// 탭이 status 를 이미 구분하므로 흐림 처리 없이 그대로 표시
class _Thumbnail extends StatelessWidget {
  final String? url;

  const _Thumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: url != null
          ? Image.network(
              url!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: 80,
        height: 80,
        color: const Color(0xFFE5E7EB),
        child: const Icon(Icons.landscape, color: Color(0xFFD1D5DB), size: 32),
      );
}

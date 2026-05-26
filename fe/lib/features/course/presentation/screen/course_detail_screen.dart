import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/domain/course_draft_detail.dart';
import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';
import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/screen/running_countdown_screen.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseDraftId;
  // 목록 카드에서 전달받는 보조 데이터 (distance, difficulty, similarityScore 등)
  final CourseDraft? draft;

  const CourseDetailScreen({
    super.key,
    required this.courseDraftId,
    this.draft,
  });

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(courseDetailProvider.notifier).load(widget.courseDraftId),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEEEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '코스를 삭제할까요?',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '삭제한 코스는 복구할 수 없습니다.',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('삭제'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final ok = await ref.read(courseDetailProvider.notifier).delete();
    if (!mounted) return;

    if (ok) {
      ref.read(courseManagementProvider.notifier).loadMyCourses();
      Navigator.of(context).pop();
    } else {
      final err = ref.read(courseDetailProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? '삭제에 실패했습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseDetailProvider);

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('코스 상세')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? '데이터를 불러오지 못했습니다',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.read(courseDetailProvider.notifier).reload(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final detail = state.detail!;
    final draft = widget.draft;
    final status = detail.status ?? draft?.status;
    final isCompleted =
        status == 'DONE' || status == 'REGISTERED';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        slivers: [
          _DetailAppBar(
            detail: detail,
            draft: draft,
            isDeleting: state.isDeleting,
            onDelete: _confirmDelete,
          ),
          SliverToBoxAdapter(
            child: _DetailBody(
              detail: detail,
              draft: draft,
              isCompleted: isCompleted,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        detail: detail,
        draft: draft,
        isCompleted: isCompleted,
        isDeleting: state.isDeleting,
      ),
    );
  }
}

// ── 앱바 (지도 or 썸네일) ───────────────────────────────────────────────
class _DetailAppBar extends StatelessWidget {
  final CourseDraftDetail detail;
  final CourseDraft? draft;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _DetailAppBar({
    required this.detail,
    required this.draft,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1C1C1E),
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Center(
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFEF4444),
                    ),
                  )
                : GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFFF7070),
                      ),
                    ),
                  ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: detail.coordinates.isNotEmpty
            ? _RouteMap(detail: detail)
            : draft?.trackImageUrl != null
                ? Image.network(
                    draft!.trackImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
      ),
    );
  }

  static Widget _placeholder() => const ColoredBox(
        color: Color(0xFFE5E7EB),
        child: Center(
          child: Icon(Icons.landscape, color: Color(0xFFD1D5DB), size: 64),
        ),
      );
}

// ── 메타 정보 영역 ─────────────────────────────────────────────────────
class _DetailBody extends StatelessWidget {
  final CourseDraftDetail detail;
  final CourseDraft? draft;
  final bool isCompleted;

  const _DetailBody({
    required this.detail,
    required this.draft,
    required this.isCompleted,
  });

  static const _statusColor = {
    'READY': Color(0xFF3B82F6),
    'DONE': Color(0xFF10B981),
    'REGISTERED': Color(0xFF8B5CF6),
  };
  static const _statusLabel = {
    'READY': '도전 전',
    'DONE': '완료',
    'REGISTERED': '등록됨',
  };
  static const _challengeDiffColor = {
    'EASY': Color(0xFF27AE60),
    'HARD': Color(0xFFE74C3C),
  };

  @override
  Widget build(BuildContext context) {
    final status = detail.status ?? draft?.status;
    final statusColor = _statusColor[status];
    final statusLabel = _statusLabel[status];
    final challengeDiff = draft?.challengeDifficulty?.toUpperCase();
    final challengeDiffColor =
        challengeDiff != null ? _challengeDiffColor[challengeDiff] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            detail.title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),

          // 상태·난이도 배지 행
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (statusColor != null && statusLabel != null)
                _Badge(label: statusLabel, color: statusColor),
              if (challengeDiff != null && challengeDiffColor != null)
                _Badge(label: challengeDiff, color: challengeDiffColor),
              if (draft?.challengeId != null)
                _Badge(label: '챌린지', color: const Color(0xFF6366F1)),
            ],
          ),
          const SizedBox(height: 20),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 16),

          // 통계 행 (거리 + 생성일)
          Row(
            children: [
              if (draft?.distance != null) ...[
                _StatChip(
                  icon: Icons.straighten_rounded,
                  label: '${draft!.distance.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 16),
              ],
              if (draft?.createdAt != null)
                _StatChip(
                  icon: Icons.calendar_today_rounded,
                  label: _formatDate(draft!.createdAt!),
                ),
            ],
          ),

          // 유사도 카드 (완료 + 점수 있을 때)
          if (isCompleted && draft?.similarityScore != null) ...[
            const SizedBox(height: 20),
            _SimilarityCard(
              score: draft!.similarityScore!,
              diffColor: challengeDiffColor,
            ),
          ],

          // 챌린지 코스 비교 카드 (기준 경로 이미지가 있을 때)
          if (detail.polygonImageUrl != null) ...[
            const SizedBox(height: 16),
            _ChallengeCourseCard(
              imageUrl: detail.polygonImageUrl!,
              title: detail.polygonTitle,
            ),
          ],

          // 경로 포인트 수
          if (detail.coordinates.isNotEmpty) ...[
            const SizedBox(height: 16),
            _StatChip(
              icon: Icons.route_rounded,
              label: '경로 포인트 ${detail.coordinates.length}개',
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
}

// ── 배지 ─────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── 통계 칩 ───────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

// ── 유사도 카드 ───────────────────────────────────────────────────────
class _SimilarityCard extends StatelessWidget {
  final double score;
  final Color? diffColor;

  const _SimilarityCard({required this.score, this.diffColor});

  @override
  Widget build(BuildContext context) {
    final color = diffColor ?? const Color(0xFF10B981);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          // 원형 진행 표시
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text(
                  '${score.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: color, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '챌린지 코스 유사도',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '내가 달린 경로와 챌린지 코스의 일치율',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  score >= 80
                      ? '아주 잘 달렸어요!'
                      : score >= 60
                          ? '훌륭한 도전이었어요'
                          : '다음엔 더 잘할 수 있어요',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 챌린지 기준 코스 카드 ─────────────────────────────────────────────
class _ChallengeCourseCard extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const _ChallengeCourseCard({required this.imageUrl, this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: const [
                Icon(Icons.flag_rounded, size: 14, color: Color(0xFF6366F1)),
                SizedBox(width: 4),
                Text(
                  '챌린지 기준 코스',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: title != null
                ? BorderRadius.zero
                : const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 140,
                color: const Color(0xFFE5E7EB),
                child: const Center(
                  child: Icon(Icons.landscape,
                      color: Color(0xFFD1D5DB), size: 40),
                ),
              ),
            ),
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Text(
                title!,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 경로 지도 (읽기 전용) ──────────────────────────────────────────────
class _RouteMap extends StatefulWidget {
  final CourseDraftDetail detail;

  const _RouteMap({required this.detail});

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  @override
  Widget build(BuildContext context) {
    final coords = widget.detail.coordinates;
    final center = coords[coords.length ~/ 2];

    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(center.latitude, center.longitude),
          zoom: 14,
        ),
        scrollGesturesEnable: false,
        zoomGesturesEnable: false,
        rotationGesturesEnable: false,
        tiltGesturesEnable: false,
        stopGesturesEnable: false,
      ),
      onMapReady: (controller) async {
        final nCoords =
            coords.map((e) => NLatLng(e.latitude, e.longitude)).toList();

        await controller.addOverlay(
          NPolylineOverlay(
            id: 'route',
            coords: nCoords,
            color: const Color(0xFF3B82F6),
            width: 4,
          ),
        );

        await controller.updateCamera(
          NCameraUpdate.fitBounds(
            NLatLngBounds.from(nCoords),
            padding: const EdgeInsets.all(40),
          ),
        );
      },
    );
  }
}

// ── 하단 버튼 바 ─────────────────────────────────────────────────────
class _BottomBar extends ConsumerWidget {
  final CourseDraftDetail detail;
  final CourseDraft? draft;
  final bool isCompleted;
  final bool isDeleting;

  const _BottomBar({
    required this.detail,
    required this.draft,
    required this.isCompleted,
    required this.isDeleting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            // 미완료 상태에서만 편집 버튼 표시
            if (!isCompleted) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CourseEditorScreen(
                                challengeId: draft?.challengeId,
                                initialNodes: detail.coordinates,
                                polygonImageUrl: detail.polygonImageUrl,
                                polygonTitle: detail.polygonTitle,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('편집'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],

            // 러닝 시작 / 다시 도전 버튼
            Expanded(
              flex: isCompleted ? 1 : 2,
              child: ElevatedButton.icon(
                onPressed: isDeleting
                    ? null
                    : () {
                        ref
                            .read(runningViewModelProvider.notifier)
                            .setSessionContext(
                              challengeId: draft?.challengeId,
                              courseId: draft?.courseId,
                              courseDraftId: draft?.courseId == null
                                  ? (draft?.courseDraftId ?? detail.editorId)
                                  : null,
                            );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RunningCountdownScreen(),
                          ),
                        );
                      },
                icon: Icon(
                  isCompleted
                      ? Icons.refresh_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(isCompleted ? '다시 도전' : '러닝 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

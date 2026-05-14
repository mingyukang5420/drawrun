import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/domain/course_draft.dart';
import 'package:running/features/course/presentation/course_management_viewmodel.dart';
import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';
import 'package:running/shared/network/api_exception.dart';

class CourseManagementScreen extends ConsumerWidget {
  const CourseManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseManagementProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const Text(
                    '내 코스 관리',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF1C1C1E)),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CourseEditorScreen()),
                    ),
                  ),
                ],
              ),
            ),
            _FilterChips(
              selected: state.selectedStatus,
              onSelect: (status) =>
                  ref.read(courseManagementProvider.notifier).selectStatus(status),
            ),
            const SizedBox(height: 4),
            Expanded(child: _CourseList(state: state, ref: ref)),
          ],
        ),
      ),
    );
  }
}

// ── 필터 칩 ───────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final CourseStatus selected;
  final ValueChanged<CourseStatus> onSelect;

  const _FilterChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: CourseStatus.values.map((status) {
          final isSelected = selected == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(status.label),
              selected: isSelected,
              onSelected: (_) => onSelect(status),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF1C1C1E),
              labelStyle: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 코스 목록 ─────────────────────────────────────────────────────────
class _CourseList extends StatelessWidget {
  final CourseManagementState state;
  final WidgetRef ref;

  const _CourseList({required this.state, required this.ref});

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
            const Icon(Icons.error_outline,
                size: 48, color: Color(0xFF9CA3AF)),
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

    if (state.drafts.isEmpty) {
      return _EmptyState(status: state.selectedStatus);
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(courseManagementProvider.notifier).loadMyCourses(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        itemCount: state.drafts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final draft = state.drafts[i];
          return _CourseDraftCard(
            draft: draft,
            onDelete: () => _confirmDelete(context, ref, draft.courseDraftId),
          );
        },
      ),
    );
  }
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
          style: TextButton.styleFrom(foregroundColor: Color(0xFFE74C3C)),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    try {
      await ref.read(courseManagementProvider.notifier).deleteCourse(courseDraftId);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다')),
        );
      }
    }
  }
}

// ── 코스 카드 ─────────────────────────────────────────────────────────
class _CourseDraftCard extends StatelessWidget {
  final CourseDraft draft;
  final VoidCallback onDelete;

  const _CourseDraftCard({required this.draft, required this.onDelete});

  static const _difficultyColor = {
    'EASY': Color(0xFF27AE60),
    'NORMAL': Color(0xFFE67E22),
    'HARD': Color(0xFFE74C3C),
  };
  static const _difficultyLabel = {
    'EASY': '쉬움',
    'NORMAL': '보통',
    'HARD': '어려움',
  };
  static const _statusColor = {
    'READY': Color(0xFF3B82F6),
    'DONE': Color(0xFF10B981),
    'REGISTERED': Color(0xFF8B5CF6),
  };
  static const _statusLabel = {
    'READY': '작성중',
    'DONE': '검증됨',
    'REGISTERED': '등록됨',
  };

  @override
  Widget build(BuildContext context) {
    final diffColor =
        _difficultyColor[draft.difficulty] ?? const Color(0xFF6B7280);
    final diffLabel =
        _difficultyLabel[draft.difficulty] ?? (draft.difficulty ?? '');
    final statusColor = _statusColor[draft.status];
    final statusLabel = _statusLabel[draft.status];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: _Thumbnail(url: draft.trackImageUrl),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        draft.title,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (statusColor != null && statusLabel != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                    if (draft.difficulty != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: diffColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          diffLabel,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: diffColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.straighten,
                        size: 13, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 2),
                    Text(
                      '${draft.distance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontFamily: 'SUIT',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    if (draft.createdAt != null) ...[
                      const Spacer(),
                      Text(
                        _formatDate(draft.createdAt!),
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const CourseEditorScreen()),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('이어서 편집'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1C1C1E),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE74C3C),
                        side: const BorderSide(color: Color(0xFFE74C3C)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
}

class _Thumbnail extends StatelessWidget {
  final String? url;

  const _Thumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return Image.network(
        url!,
        height: 140,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        height: 140,
        width: double.infinity,
        color: const Color(0xFFE5E7EB),
        child:
            const Icon(Icons.landscape, color: Color(0xFFD1D5DB), size: 48),
      );
}

// ── 빈 상태 위젯 ──────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final CourseStatus status;

  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, message, sub) = switch (status) {
      CourseStatus.all => (
          Icons.route_outlined,
          '등록된 코스가 없습니다',
          '새 코스를 만들어 보세요'
        ),
      CourseStatus.ready => (
          Icons.edit_note_outlined,
          '작성 중인 코스가 없습니다',
          '코스 편집을 시작해 보세요'
        ),
      CourseStatus.done => (
          Icons.check_circle_outline,
          '검증된 코스가 없습니다',
          '코스를 완주하면 검증됩니다'
        ),
      CourseStatus.registered => (
          Icons.public_outlined,
          '등록된 코스가 없습니다',
          '검증된 코스를 등록해 보세요'
        ),
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

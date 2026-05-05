import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/course_viewmodel.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';

// 코스 목록 화면
// 서버에서 코스를 불러와 카드 목록으로 표시하고, 편집 화면 진입을 제공
class CourseScreen extends ConsumerWidget {
  const CourseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseViewModelProvider);
    final notifier = ref.read(courseViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 영역: 제목 + 생성하기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Text(
                    '코스',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // 편집 화면으로 이동하는 생성하기 버튼
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CourseEditorScreen(),
                        ),
                      ).then((_) {
                        // 편집 화면에서 돌아오면 목록을 새로고침
                        ref
                            .read(courseViewModelProvider.notifier)
                            .loadCourses();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      '+ 생성하기',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 검색 바 + 필터 버튼 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // 코스 검색 입력창 (검색 기능 추후 연동)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: '코스 검색',
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 14),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 필터 버튼 (추후 난이도·거리 필터 연동)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '필터',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 코스 카드 목록
            Expanded(child: _buildBody(state, notifier)),
          ],
        ),
      ),
    );
  }

  // 로딩·오류·빈 목록·정상 상태에 따라 다른 위젯을 반환
  Widget _buildBody(CourseState state, CourseNotifier notifier) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: notifier.loadCourses,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (state.courses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              '저장된 코스가 없습니다',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '상단 버튼으로 첫 코스를 만들어보세요',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: state.courses.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _CourseCard(
          course: state.courses[index],
          onDelete: state.courses[index].id != null
              ? () => notifier.deleteCourse(state.courses[index].id!)
              : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 코스 목록 카드
// 섬네일 · 코스명 · 거리/지역 · 완주 상태 · 난이도 배지를 표시
// ─────────────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final Course course;

  // null 이면 삭제 버튼 비활성 (id 가 없는 코스)
  final VoidCallback? onDelete;

  const _CourseCard({required this.course, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 코스 경로 미리보기 섬네일
            _CourseThumbnail(url: course.thumbnailUrl),
            const SizedBox(width: 14),

            // 코스 정보 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 코스 이름
                      Expanded(
                        child: Text(
                          course.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 난이도 배지 (EASY/NORMAL/HARD)
                      if (course.difficulty != null)
                        _DifficultyBadge(difficulty: course.difficulty!),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 거리 + 지역 정보
                  Text(
                    '${course.distance.toStringAsFixed(1)}km'
                    '  ${course.regions.join(' ')}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // 완주 여부 또는 완주율
                  _CompletionText(
                    isCompleted: course.isCompleted,
                    score: course.completionScore,
                  ),
                ],
              ),
            ),

            // 삭제 버튼 (카드 우측 하단에 배치)
            if (onDelete != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.grey,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 코스 섬네일 위젯
// thumbnailUrl 이 있으면 네트워크 이미지, 없으면 기본 경로 아이콘 표시
class _CourseThumbnail extends StatelessWidget {
  final String? url;

  const _CourseThumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 80,
        height: 80,
        // 이미지 로드 전 표시되는 베이지 계열 배경색
        color: const Color(0xFFF0EDE8),
        child: url != null
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                // 이미지 로드 실패 시 기본 아이콘으로 대체
                errorBuilder: (_, __, ___) => const _ThumbnailPlaceholder(),
              )
            : const _ThumbnailPlaceholder(),
      ),
    );
  }
}

// 섬네일 이미지 미제공 또는 로드 실패 시 표시할 경로 아이콘
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.route, size: 36, color: Color(0xFFFF5722)),
    );
  }
}

// 난이도 배지 위젯
// EASY → 초록, NORMAL → 주황, HARD → 빨강 텍스트로 표시
class _DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const _DifficultyBadge({required this.difficulty});

  // 난이도별 색상 매핑
  static const _colors = {
    'EASY': Color(0xFF27AE60),
    'NORMAL': Color(0xFFE67E22),
    'HARD': Color(0xFFE74C3C),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[difficulty] ?? Colors.grey;
    return Text(
      difficulty,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
}

// 완주 상태 텍스트 위젯
// 완주 → "완주", 부분 완주 → "완주율 N%", 미도전 → 빈 공간
class _CompletionText extends StatelessWidget {
  final bool isCompleted;
  final int score;

  const _CompletionText({required this.isCompleted, required this.score});

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return const Text(
        '완주',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }
    if (score > 0) {
      return Text(
        '완주율 $score%',
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      );
    }
    // 미도전 코스는 완주 정보를 표시하지 않음
    return const SizedBox.shrink();
  }
}

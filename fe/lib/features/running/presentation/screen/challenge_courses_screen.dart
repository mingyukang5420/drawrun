import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course.dart';
import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/course_viewmodel.dart';

// 챌린지 코스 목록 화면
// Easy 또는 Hard 난이도로 필터링된 코스 목록을 보여준다
// 사용자는 코스의 도형 이미지를 보고 도전할 코스를 선택한다
class ChallengeCoursesScreen extends ConsumerStatefulWidget {
  // 서버 필터에 사용할 난이도 문자열 (예: 'EASY', 'HARD')
  final String difficulty;

  // 앱바에 표시할 화면 제목
  final String title;

  const ChallengeCoursesScreen({
    super.key,
    required this.difficulty,
    required this.title,
  });

  @override
  ConsumerState<ChallengeCoursesScreen> createState() =>
      _ChallengeCoursesScreenState();
}

class _ChallengeCoursesScreenState
    extends ConsumerState<ChallengeCoursesScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 처음 열릴 때 코스 목록 로드
    Future.microtask(
      () => ref.read(courseViewModelProvider.notifier).loadCourses(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseViewModelProvider);

    // difficulty 에 맞는 코스만 클라이언트 측 필터링
    // TODO: 백엔드에서 난이도 필터 API 지원 시 서버 쿼리 파라미터로 교체
    final filtered = state.courses
        .where((c) => c.difficulty?.toUpperCase() == widget.difficulty)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ),
      body: _buildBody(state, filtered),
    );
  }

  Widget _buildBody(CourseState state, List<Course> filtered) {
    // 로딩 중
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 에러 발생
    if (state.errorMessage != null && filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(courseViewModelProvider.notifier).loadCourses(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    // 해당 난이도 코스 없음
    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              '이 난이도의 코스가 아직 없습니다',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    // 코스 목록 카드 리스트
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _CourseChallengeCard(course: filtered[i]),
    );
  }
}

// ── 개별 코스 카드 ────────────────────────────────────────────────────────
// 도형 이미지(썸네일) + 코스 제목 + 참여 정보를 한 장의 카드로 표현
class _CourseChallengeCard extends StatelessWidget {
  final Course course;

  const _CourseChallengeCard({required this.course});

  // 난이도별 색상 (배지와 강조선에 사용)
  static const _difficultyColor = {
    'EASY': Color(0xFF27AE60),
    'BEGINNER': Color(0xFF27AE60),
    'NORMAL': Color(0xFFE67E22),
    'HARD': Color(0xFFE74C3C),
  };

  @override
  Widget build(BuildContext context) {
    final difficulty = course.difficulty?.toUpperCase() ?? '';
    final accentColor =
        _difficultyColor[difficulty] ?? const Color(0xFF6B7280);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: () {
          // TODO: 공개 코스 상세 화면 연결 (백엔드 API 확정 후 구현)
          // 현재는 안내 메시지로 대체
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${course.title} 챌린지를 준비 중입니다'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Row(
          children: [
            // 좌측: 도형 이미지 (썸네일 URL 있으면 네트워크, 없으면 플레이스홀더)
            _ShapeThumbnail(url: course.thumbnailUrl, color: accentColor),

            // 우측: 코스 정보
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 코스 제목
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 거리 정보
                    Row(
                      children: [
                        const Icon(
                          Icons.straighten,
                          size: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${course.distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 완주율 + 도전 안내 버튼
                    Row(
                      children: [
                        if (course.completionScore > 0) ...[
                          Text(
                            '완주율 ${course.completionScore}%',
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        // 도전하기 텍스트 버튼
                        Text(
                          '도전하기 →',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
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

// ── 도형 썸네일 이미지 ────────────────────────────────────────────────────
// 백엔드가 제공하는 도형 이미지 URL을 표시하는 위젯
// URL이 없거나 로드 실패 시 난이도 색상 플레이스홀더로 대체
class _ShapeThumbnail extends StatelessWidget {
  // 도형 이미지 URL (백엔드 제공, 없으면 null)
  final String? url;

  // 플레이스홀더에 사용할 난이도 색상
  final Color color;

  const _ShapeThumbnail({this.url, required this.color});

  @override
  Widget build(BuildContext context) {
    // URL이 있으면 네트워크 이미지 표시, 없으면 플레이스홀더
    if (url != null) {
      return Image.network(
        url!,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        // 이미지 로드 실패 시 플레이스홀더로 폴백
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  // 도형 이미지가 없을 때 보여주는 색상 플레이스홀더
  Widget _placeholder() => Container(
        width: 88,
        height: 88,
        color: color.withValues(alpha: 0.1),
        child: Icon(
          Icons.pentagon_outlined,
          color: color.withValues(alpha: 0.5),
          size: 36,
        ),
      );
}

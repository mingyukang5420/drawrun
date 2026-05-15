import 'package:flutter/material.dart';

import 'package:running/features/challenge/data/mock_challenge_data.dart';
import 'package:running/features/challenge/domain/challenge_course.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';

// 챌린지 코스 선택 화면 — 디자인 시안 4번 화면.
//
// 사용자 동선:
//   - 이전 화면(ChallengeScreen) 의 "시작하기" → 다이얼로그에서 "예" → 이 화면 진입
//   - 코스 항목의 시작/편집 동작은 본 작업에서 다루지 않음 (디자인만)
//   - 하단 "+ 새로 그리기" → CourseEditorScreen 으로 이동
class ChallengeCourseSelectScreen extends StatelessWidget {
  const ChallengeCourseSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const courses = kMockChallengeCourses;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '코스 선택',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 상단 안내 — "내가 한 코스 가져오기" 같은 보조 라벨.
            // 디자인상 작은 회색 텍스트 한 줄로 깔린다.
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '내가 한 코스 가져오기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),

            // 코스 카드 목록 — 남은 영역을 채우며 스크롤.
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                itemCount: courses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ChallengeCourseRow(course: courses[i]),
              ),
            ),

            // 하단 "+ 새로 그리기" — CourseEditorScreen 으로 이동.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CourseEditorScreen(),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1C1C1E),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    '새로 그리기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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

// 코스 한 줄.
//
// 좌측 별 아이콘 + 이름/거리 + 우측 동작 아이콘 두 개(편집/시작).
// 본 화면은 디자인 검증용이라 동작 아이콘은 탭해도 아무 일 안 한다 (콜백 null).
class _ChallengeCourseRow extends StatelessWidget {
  final ChallengeCourse course;

  const _ChallengeCourseRow({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // 별 아이콘 — 챌린지 도장과 시각적 통일.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8C4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFC107),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // 이름 + 거리.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${course.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontFamily: 'SUIT',
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // 편집 아이콘 (동작 안 함 — 디자인만).
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: const Color(0xFF6B7280),
            onPressed: null,
            tooltip: '편집 (준비 중)',
          ),
          // 시작 아이콘 (동작 안 함 — 디자인만).
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            color: const Color(0xFF1C1C1E),
            onPressed: null,
            tooltip: '시작 (준비 중)',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/core/theme/app_text_style.dart';
import 'package:running/features/bookmark/presentation/bookmark_provider.dart';
import 'package:running/features/bookmark/presentation/bookmarked_courses_viewmodel.dart';
import 'package:running/features/course/domain/course.dart';
import 'package:running/features/mypage/presentation/screen/mypage_screen.dart';
import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/screen/running_countdown_screen.dart';
import 'package:running/features/running/presentation/widgets/running_map_view.dart';

class RunningScreen extends ConsumerWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(runningViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            _BookmarkedCourses(),
            Expanded(
              child: Stack(
                children: [const RunningMapView(), const _MapVignette()],
              ),
            ),
            _FreeRunButton(
              onPressed: () async {
                await notifier.clear();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RunningCountdownScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 헤더: 프로필 아바타(좌) + 인사·날씨(우) 한 줄 ─────────────────
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherState = ref.watch(weatherProvider);

    final messageText = weatherState.weather?.message ?? '오늘도 달리기 좋은 날씨예요!';
    final locationText = weatherState.weather?.locationLine ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 프로필 아바타 — 탭 시 마이페이지로 이동
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MypageScreen()),
            ),
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFE5E7EB),
              child: Icon(Icons.person, color: Color(0xFF9CA3AF), size: 26),
            ),
          ),
          const SizedBox(width: 14),
          // 인사 + 날씨
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messageText,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                if (weatherState.isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  Text(
                    locationText,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
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

// ── 북마크한 코스 캐러셀: PageView + 인디케이터 ────────────────────
class _BookmarkedCourses extends ConsumerStatefulWidget {
  const _BookmarkedCourses();

  @override
  ConsumerState<_BookmarkedCourses> createState() => _BookmarkedCoursesState();
}

class _BookmarkedCoursesState extends ConsumerState<_BookmarkedCourses> {
  // 한 카드가 차지할 viewport 비율.
  // 작을수록 한 화면에 카드가 좁게 그려지고 옆 카드의 일부가 함께 보인다.
  static const _viewportFraction = 0.78;

  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: _viewportFraction);
    _controller.addListener(() {
      final page = _controller.page?.round() ?? 0;
      if (page != _currentPage) setState(() => _currentPage = page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 서버에서 받은 최신 5개 북마크 (또는 그 이하).
    final state = ref.watch(bookmarkedCoursesProvider);
    final courses = state.courses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 섹션 헤더 ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Row(
            children: [
              Text('북마크한 코스', style: AppTextStyle.button),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF6B7280),
                size: 24,
              ),
            ],
          ),
        ),

        // ── 본체: 로딩 / 빈 상태 / 카드 리스트 분기 ───────────
        SizedBox(
          height: 96,
          child: _buildBody(state, courses),
        ),

        // ── 페이지 인디케이터 ────────────────────────────────
        // 카드가 한 장도 없으면 인디케이터를 그리지 않는다.
        if (courses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(courses.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFF9CA3AF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // 로딩 / 에러 / 빈 / 카드 리스트 네 분기.
  Widget _buildBody(BookmarkedCoursesState state, List<Course> courses) {
    if (state.isLoading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (state.errorMessage != null && courses.isEmpty) {
      // 초기 로드 실패 — 재시도 버튼만 한 줄 노출.
      return Center(
        child: TextButton.icon(
          onPressed: ref.read(bookmarkedCoursesProvider.notifier).load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('다시 불러오기'),
        ),
      );
    }

    // 빈 결과 + + 버튼 한 장만.
    // 카드가 0개여도 사용자가 북마크 페이지로 갈 수 있게 + 버튼은 항상 그린다.
    return PageView.builder(
      clipBehavior: Clip.none,
      padEnds: false,
      controller: _controller,
      physics: _BoundedPageScrollPhysics(
        maxPage: courses.isEmpty ? 0 : courses.length - 1,
        viewportFraction: _viewportFraction,
      ),
      itemCount: courses.length + 1,
      itemBuilder: (_, i) {
        if (i == courses.length) {
          // 마지막 자리에 + 버튼.
          // 이번 커밋에선 아직 라우팅이 없으므로 onTap 은 비워둔다.
          // (커밋 4 에서 BookmarkListScreen 으로 push 한다.)
          return Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: 4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width:
                  MediaQuery.of(context).size.width *
                      (1 - _viewportFraction) -
                      40,
                  height:
                  MediaQuery.of(context).size.width *
                      (1 - _viewportFraction) -
                      40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color.fromARGB(255, 243, 243, 243),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF9CA3AF),
                    size: 18,
                  ),
                ),
              ),
            ),
          );
        }

        final course = courses[i];
        // 카드 한 장 + 탭 시 상세 화면(placeholder).
        return Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 4,
            top: 4,
            bottom: 4,
          ),
          child: _CourseCard(
            course: course,
            onTap: course.id != null
                ? () => _openCourseDetail(context, course.id!)
                : null,
          ),
        );
      },
    );
  }

  // 코스 상세 화면 진입 placeholder.
  //
  // 코스 상세 화면(CourseDetailScreen) 은 다른 팀원이 별도 PR 로 작업 중이다.
  // 머지가 들어오면 아래 SnackBar 를 다음 한 줄로 교체:
  //   Navigator.of(context).push(MaterialPageRoute(
  //     builder: (_) => CourseDetailScreen(courseId: courseId),
  //   ));
  //
  // 그 시점에 이 파일 상단에 CourseDetailScreen import 한 줄도 같이 추가하면 끝.
  void _openCourseDetail(BuildContext context, int courseId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('코스 상세 화면은 별도 작업 중입니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ── 코스 카드 위젯 ─────────────────────────────────────────────────
// 러닝 메인 화면 상단 캐러셀에서 한 장씩 보여주는 카드.
// 도메인 Course 를 그대로 받아 표현한다 (별도 _CourseItem 같은 가짜 모델 없음).
class _CourseCard extends StatelessWidget {
  final Course course;

  // 카드 탭 시 실행할 콜백. null 이면 비활성(ripple 없음).
  final VoidCallback? onTap;

  const _CourseCard({required this.course, this.onTap});

  // 난이도별 색상 / 한글 라벨.
  static const _difficultyColor = {
    'EASY': Color(0xFF27AE60),
    'NORMAL': Color(0xFFE67E22),
    'HARD': Color(0xFFE74C3C),
  };
  static const _difficultyLabel = {'EASY': '쉬움', 'NORMAL': '보통', 'HARD': '어려움'};

  @override
  Widget build(BuildContext context) {
    final difficulty = course.difficulty ?? '';
    final diffColor =
        _difficultyColor[difficulty] ?? const Color(0xFF6B7280);
    final diffLabel = _difficultyLabel[difficulty] ?? difficulty;
    final hasProgress =
        course.completionScore > 0 && course.completionScore < 100;
    final isCompleted = course.completionScore >= 100;

    // Material + InkWell:
    //   - Material 이 ripple 을 그릴 표면.
    //   - InkWell 이 onTap 과 ripple 책임.
    //   - 카드 모서리(16) 와 InkWell.borderRadius 를 같은 값으로 맞춰
    //     ripple 이 카드 모서리를 넘지 않게 함.
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withOpacity(0.07),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // 좌측 정사각형 썸네일.
            _Thumbnail(url: course.thumbnailUrl),
            // 우측 텍스트 영역.
            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 코스명 + 난이도 배지.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1C1C1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (course.difficulty != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: diffColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
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
                    // 지역 + 거리.
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            course.regions.join(' · '),
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${course.distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontFamily: 'SUIT',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    // 진행 중인 코스만 진행률 바.
                    if (hasProgress)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: course.completionScore / 100,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor:
                          AlwaysStoppedAnimation<Color>(diffColor),
                        ),
                      ),
                    // 완주 텍스트.
                    if (isCompleted)
                      const Text(
                        '완주 ✓',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF27AE60),
                        ),
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

// 썸네일 이미지: URL 있으면 네트워크, 없으면 플레이스홀더
class _Thumbnail extends StatelessWidget {
  final String? url;

  const _Thumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return Image.network(
        url!,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    width: 88,
    height: 88,
    color: const Color(0xFFE5E7EB),
    child: const Icon(Icons.landscape, color: Color(0xFFD1D5DB), size: 32),
  );
}

// ── 지도 원형 비네팅 ────────────────────────────────────────────────
// 지도 중앙(= 사용자 위치)을 중심으로 원형으로 흰색이 자연스럽게 페이드인.
// CustomPainter 로 직접 캔버스에 그려 위젯 크기 문제를 회피한다.
// IgnorePointer 로 감싸 지도 터치 이벤트는 그대로 통과시킨다.
class _MapVignette extends StatelessWidget {
  const _MapVignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _VignettePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.longestSide * 0.6;

    final shader =
        RadialGradient(
          colors: const [Color(0x00FFFFFF), Colors.white],
          stops: const [0.15, 0.7],
        ).createShader(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * 2,
          ),
        );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 커스텀 스크롤 물리: maxPage 이후 스냅 방지 ─────────────────────────
class _BoundedPageScrollPhysics extends PageScrollPhysics {
  final int maxPage;
  final double viewportFraction;

  const _BoundedPageScrollPhysics({
    required this.maxPage,
    required this.viewportFraction,
    super.parent,
  });

  @override
  _BoundedPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _BoundedPageScrollPhysics(
        maxPage: maxPage,
        viewportFraction: viewportFraction,
        parent: buildParent(ancestor),
      );

  double _maxExtent(ScrollMetrics pos) =>
      maxPage * viewportFraction * pos.viewportDimension;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final maxExtent = _maxExtent(position);
    if (value > maxExtent && position.pixels < maxExtent) {
      return value - maxExtent;
    }
    if (value > maxExtent && position.pixels >= maxExtent) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

// ── 자유 러닝 시작 버튼 ──────────────────────────────────────────────
class _FreeRunButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _FreeRunButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C1C1E),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '자유 러닝',
                style: TextStyle(
                  fontFamily: 'SUIT',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFD60A),
                ),
              ),
              SizedBox(width: 6),
              Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFFFFD60A),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

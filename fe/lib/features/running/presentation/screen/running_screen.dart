import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/core/theme/app_text_style.dart';
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
class _BookmarkedCourses extends StatefulWidget {
  const _BookmarkedCourses();

  @override
  State<_BookmarkedCourses> createState() => _BookmarkedCoursesState();
}

class _BookmarkedCoursesState extends State<_BookmarkedCourses> {
  // TODO: 북마크 API 연동 후 서버 데이터로 교체
  static const _items = [
    _CourseItem(
      title: '한강 러닝코스',
      difficulty: 'EASY',
      distance: 3.5,
      regions: ['성동구', '관악구'],
      completionScore: 65,
    ),
    _CourseItem(
      title: '석촌호수 코스',
      difficulty: 'NORMAL',
      distance: 3.8,
      regions: ['송파구'],
      completionScore: 0,
    ),
    _CourseItem(
      title: '서울숲 코스',
      difficulty: 'HARD',
      distance: 6.2,
      regions: ['성동구'],
      completionScore: 100,
    ),
  ];

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        SizedBox(
          height: 96,
          child: PageView.builder(
            clipBehavior: Clip.none,
            padEnds: false,
            controller: _controller,
            physics: _BoundedPageScrollPhysics(
              maxPage: _items.length - 1,
              viewportFraction: _viewportFraction,
            ),
            itemCount: _items.length + 1,
            itemBuilder: (_, i) {
              if (i == _items.length) {
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

              return Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 4,
                  top: 4,
                  bottom: 4,
                ),
                child: _CourseCard(item: _items[i]),
              );
            },
          ),
        ),
        // 페이지 인디케이터
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_items.length, (i) {
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
}

// ── 코스 카드 데이터 (Course 도메인 필드 반영) ─────────────────────
class _CourseItem {
  final String title;
  final String difficulty; // 'EASY' | 'NORMAL' | 'HARD'
  final double distance; // km
  final List<String> regions;
  final String? thumbnailUrl;
  final int completionScore; // 0~100

  const _CourseItem({
    required this.title,
    required this.difficulty,
    required this.distance,
    required this.regions,
    this.thumbnailUrl,
    this.completionScore = 0,
  });
}

// ── 코스 카드 위젯 ─────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final _CourseItem item;

  const _CourseCard({required this.item});

  // 난이도별 색상 및 한글 라벨
  static const _difficultyColor = {
    'EASY': Color(0xFF27AE60),
    'NORMAL': Color(0xFFE67E22),
    'HARD': Color(0xFFE74C3C),
  };
  static const _difficultyLabel = {'EASY': '쉬움', 'NORMAL': '보통', 'HARD': '어려움'};

  @override
  Widget build(BuildContext context) {
    final diffColor =
        _difficultyColor[item.difficulty] ?? const Color(0xFF6B7280);
    final diffLabel = _difficultyLabel[item.difficulty] ?? item.difficulty;
    final hasProgress = item.completionScore > 0 && item.completionScore < 100;
    final isCompleted = item.completionScore >= 100;

    return Container(
      clipBehavior: Clip.antiAlias,
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
      child: Row(
        children: [
          // ── 소형 썸네일 (좌측 정사각형) ──
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(16),
            ),
            child: _Thumbnail(url: item.thumbnailUrl),
          ),
          // ── 텍스트 정보 (우측) ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 코스명 + 난이도 배지
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
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
                  ),
                  // 지역 + 거리
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
                          item.regions.join(' · '),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontFamily: 'SUIT',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  // 진행률 바 (진행 중인 코스만)
                  if (hasProgress)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: item.completionScore / 100,
                        minHeight: 4,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(diffColor),
                      ),
                    ),
                  // 완주 텍스트
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/core/theme/app_text_style.dart';
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
            // 지도: 상하좌우 가장자리를 배경색(흰색)으로 자연스럽게 페이드
            Expanded(
              child: Stack(
                children: [
                  const RunningMapView(),
                  const _MapVignette(),
                ],
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
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 프로필 아바타 (TODO: 실제 프로필 이미지로 교체)
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFFE5E7EB),
            child: Icon(Icons.person, color: Color(0xFF9CA3AF), size: 26),
          ),
          const SizedBox(width: 14),
          // 인사 + 날씨
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘도 달리기 좋은 날씨예요! ☀️',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                // TODO: 위치·날씨 API 연동 후 동적 데이터로 교체
                Text(
                  '서울특별시 18°C 맑음',
                  style: TextStyle(
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

  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
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
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            children: [
              Text('북마크한 코스', style: AppTextStyle.titleMedium),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 22),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _controller,
            itemCount: _items.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _CourseCard(item: _items[i]),
            ),
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
                      : const Color(0xFFD1D5DB),
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
  final String difficulty;      // 'EASY' | 'NORMAL' | 'HARD'
  final double distance;         // km
  final List<String> regions;
  final String? thumbnailUrl;
  final int completionScore;    // 0~100

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
  static const _difficultyLabel = {
    'EASY': '쉬움',
    'NORMAL': '보통',
    'HARD': '어려움',
  };

  @override
  Widget build(BuildContext context) {
    final diffColor =
        _difficultyColor[item.difficulty] ?? const Color(0xFF6B7280);
    final diffLabel = _difficultyLabel[item.difficulty] ?? item.difficulty;
    final hasProgress = item.completionScore > 0 && item.completionScore < 100;
    final isCompleted = item.completionScore >= 100;

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
      child: Row(
        children: [
          // ── 소형 썸네일 (좌측 정사각형) ──
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
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
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
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
                  ),
                  // 지역 + 거리
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 12, color: Color(0xFF9CA3AF)),
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

// ── 지도 가장자리 페이드 비네팅 ─────────────────────────────────────
// 상하좌우에서 흰색 → 투명 그라데이션을 올려 배경과 자연스럽게 섞이게 한다.
// IgnorePointer 로 감싸 지도 터치 이벤트는 그대로 통과시킨다.
class _MapVignette extends StatelessWidget {
  const _MapVignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            // 중앙 투명 → 바깥쪽 흰색으로 퍼지는 원형 그라데이션
            // radius 를 1.4 로 키우면 코너까지 충분히 덮인다
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.4,
              colors: [Color(0x00FFFFFF), Colors.white],
              stops: [0.45, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 자유 러닝 시작 버튼 ──────────────────────────────────────────────
class _FreeRunButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _FreeRunButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              Icon(Icons.play_arrow_rounded,
                  color: Color(0xFFFFD60A), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

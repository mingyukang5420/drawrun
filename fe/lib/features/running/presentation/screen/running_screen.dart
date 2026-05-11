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
            _TopBar(),
            _Greeting(),
            _BookmarkedCourses(),
            // 지도는 남은 공간을 모두 차지
            const Expanded(child: RunningMapView()),
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

// ── 상단 바: 프로필 아바타(좌) + 북마크 아이콘(우) ─────────────────
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 프로필 아바타 (TODO: 실제 프로필 이미지로 교체)
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFE5E7EB),
            child: Icon(Icons.person, color: Color(0xFF9CA3AF), size: 22),
          ),
          // 빠른 경로(북마크) 이동 버튼
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.bookmark_border_rounded,
              size: 26,
              color: Color(0xFF1C1C1E),
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

// ── 인사 문구 + 날씨 ─────────────────────────────────────────────────
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘도 달리기 좋은 날씨예요!',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 4),
          // TODO: 위치·날씨 API 연동 후 동적 데이터로 교체
          Text(
            '서울특별시 송파구 18°C 맑음 ☀️',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: Color(0xFF9CA3AF),
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
      badge: '추천',
      badgeColor: Color(0xFF3B82F6),
      name: '한강공원 코스',
      distance: '5.2km',
      time: '32분',
    ),
    _CourseItem(
      badge: '인기',
      badgeColor: Color(0xFFF59E0B),
      name: '석촌호수 코스',
      distance: '3.8km',
      time: '24분',
    ),
    _CourseItem(
      badge: '신규',
      badgeColor: Color(0xFF6B7280),
      name: '서울숲 코스',
      distance: '4.6km',
      time: '28분',
    ),
  ];

  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // viewportFraction < 1 → 옆 카드가 살짝 보이는 캐러셀 효과
    _controller = PageController(viewportFraction: 0.82);
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
        // 섹션 헤더
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
        // 캐러셀 PageView
        SizedBox(
          height: 185,
          child: PageView.builder(
            controller: _controller,
            itemCount: _items.length,
            itemBuilder: (_, i) => Padding(
              // 카드 간격: 좌우 6px
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

// ── 코스 카드 데이터 ───────────────────────────────────────────────
class _CourseItem {
  final String badge;
  final Color badgeColor;
  final String name;
  final String distance;
  final String time;

  const _CourseItem({
    required this.badge,
    required this.badgeColor,
    required this.name,
    required this.distance,
    required this.time,
  });
}

// ── 코스 카드 위젯 ─────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final _CourseItem item;

  const _CourseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      // 너비는 PageView의 viewportFraction이 결정 — 명시적 width 불필요
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 영역 + 배지 오버레이
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                // TODO: 실제 코스 이미지로 교체
                Container(
                  height: 115,
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(
                    Icons.landscape,
                    color: Color(0xFFD1D5DB),
                    size: 36,
                  ),
                ),
                // 배지 (추천·인기·신규)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: item.badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.badge,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 코스명 + 거리·시간
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.distance} · ${item.time}',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
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

// ── 자유 러닝 시작 버튼 ─────────────────────────────────────────────
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                '바로 달리기 시작',
                style: TextStyle(
                  fontFamily: 'SUIT',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

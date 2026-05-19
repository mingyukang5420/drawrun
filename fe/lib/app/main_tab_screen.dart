import 'package:flutter/material.dart';

// 각 탭 화면 임포트
import 'package:running/features/course/presentation/screen/course_management_screen.dart';
import 'package:running/features/ranking/presentation/screen/ranking_screen.dart';
import 'package:running/features/running/presentation/screen/running_screen.dart';

// 앱의 하단 탭 네비게이션 전체를 관리하는 위젯
// 탭 구성: 코스(왼쪽) → 챌린지(가운데, 기본) → 랭킹(오른쪽)
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  // 현재 선택된 탭 번호 (0: 코스, 1: 챌린지, 2: 랭킹)
  // 1번(챌린지)을 기본값으로 설정 — 앱 시작 시 챌린지 허브가 가장 먼저 보임
  int _selectedIndex = 1;

  // 탭 인덱스 순서와 동일하게 화면 목록 구성
  final List<Widget> _pages = const [
    CourseManagementScreen(), // 탭 0: GPS 드로우 코스 생성·관리
    RunningScreen(),          // 탭 1: 챌린지 시작 또는 자유 러닝 선택 허브
    RankingScreen(),          // 탭 2: Easy·Hard 주차별 챌린지 랭킹
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 선택된 탭에 해당하는 화면만 표시
      body: _pages[_selectedIndex],

      // 탭을 누르면 인덱스를 갱신하고 화면을 전환
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ── 커스텀 하단 내비게이션 바 ────────────────────────────────────────────
// 검정 둥근 직사각형 바. 선택 항목만 흰 원으로 강조, 라벨 없음.
// 아이콘: 코스(route) · 챌린지(달리기) · 랭킹(트로피)
class _CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNav({required this.currentIndex, required this.onTap});

  static const _icons = [
    Icons.route_rounded,
    Icons.directions_run_rounded,
    Icons.emoji_events_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding + 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: List.generate(_icons.length, (i) {
            final selected = i == currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _icons[i],
                      size: 24,
                      color: selected
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

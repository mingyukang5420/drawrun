import 'package:flutter/material.dart';

// 각 탭 화면 임포트
import 'package:running/features/course/presentation/screen/course_management_screen.dart';
import 'package:running/features/running/presentation/screen/running_screen.dart';
import 'package:running/features/record/presentation/screen/record_screen.dart';

// 앱의 하단 탭 네비게이션 전체를 관리하는 위젯
// 탭 구성: 코스(왼쪽) → 홈/챌린지(가운데, 기본) → 기록/랭킹(오른쪽)
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  // 현재 선택된 탭 번호 (0: 코스, 1: 홈, 2: 기록)
  // 1번(홈)을 기본값으로 설정 — 앱 시작 시 챌린지 허브가 가장 먼저 보임
  int _selectedIndex = 1;

  // 탭 인덱스 순서와 동일하게 화면 목록 구성
  final List<Widget> _pages = const [
    CourseManagementScreen(), // 탭 0: GPS 드로우 코스 생성·관리
    RunningScreen(),          // 탭 1: 챌린지 시작 또는 자유 러닝 선택 허브
    RecordScreen(),           // 탭 2: 내 기록 + 코스별 랭킹 확인
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 선택된 탭에 해당하는 화면만 표시
      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,

        // 탭을 누르면 인덱스를 갱신하고 화면을 전환
        onTap: (i) => setState(() => _selectedIndex = i),

        type: BottomNavigationBarType.fixed,

        // 선택된 탭 색상 (진한 검정)
        selectedItemColor: const Color(0xFF1C1C1E),

        // 비선택 탭 색상 (회색)
        unselectedItemColor: const Color(0xFF9CA3AF),

        // 선택된 라벨 폰트 크기
        selectedFontSize: 12,
        unselectedFontSize: 12,

        items: const [
          // 탭 0: 코스 관리
          BottomNavigationBarItem(
            icon: Icon(Icons.route_outlined),
            activeIcon: Icon(Icons.route),
            label: '코스',
          ),

          // 탭 1: 홈(챌린지/자유 러닝 선택) — 앱의 핵심 기능
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run_outlined),
            activeIcon: Icon(Icons.directions_run),
            label: '홈',
          ),

          // 탭 2: 기록 + 랭킹
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: '기록',
          ),
        ],
      ),
    );
  }
}

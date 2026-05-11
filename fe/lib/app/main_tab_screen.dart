import 'package:flutter/material.dart';

import 'package:running/features/running/presentation/screen/running_screen.dart';
import 'package:running/features/course/presentation/screen/course_search_screen.dart';
import 'package:running/features/course/presentation/screen/course_management_screen.dart';
import 'package:running/features/record/presentation/screen/record_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  // 0:러닝  1:코스탐색  2:코스관리  3:내기록
  int index = 0;

  final List<Widget> pages = const [
    RunningScreen(),
    CourseSearchScreen(),
    CourseManagementScreen(),
    RecordScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        type: BottomNavigationBarType.fixed, // 4개 이상은 fixed 필수
        selectedItemColor: const Color(0xFF1C1C1E),
        unselectedItemColor: const Color(0xFF9CA3AF),

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run_outlined),
            activeIcon: Icon(Icons.directions_run),
            label: '러닝',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '코스 탐색',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route_outlined),
            activeIcon: Icon(Icons.route),
            label: '코스 관리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: '내 기록',
          ),
        ],
      ),
    );
  }
}
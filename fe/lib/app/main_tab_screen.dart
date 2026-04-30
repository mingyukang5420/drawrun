import 'package:flutter/material.dart';

import 'package:running/features/course/screen/course_screen.dart';
import 'package:running/features/running/presentation/screen/running_screen.dart';
import 'package:running/features/record/screen/record_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int index = 1; // 러닝이 기본

  final List<Widget> pages = const [
    CourseScreen(),
    RunningScreen(),
    RecordScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '코스',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.run_circle),
            label: '러닝',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: '기록',
          ),
        ],
      ),
    );
  }
}
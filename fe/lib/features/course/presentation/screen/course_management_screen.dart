import 'package:flutter/material.dart';

// 코스 관리 화면 — 내가 만든 코스를 관리(수정·삭제)하는 화면
// TODO: 코스 관리 API 연동 후 구현
class CourseManagementScreen extends StatelessWidget {
  const CourseManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                '코스 관리',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '준비 중입니다',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

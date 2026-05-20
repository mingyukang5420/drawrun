import 'package:flutter/material.dart';

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 앱 로고 이미지 (drawrun_logo.png)
        ClipRRect(
          child: Image.asset(
            'assets/icon/drawrun_logo.png',
            width: 165,
            height: 140,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          '나만의 러닝 코스를 기록하고\n공유하세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w400,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}
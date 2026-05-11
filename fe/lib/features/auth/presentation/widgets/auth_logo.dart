import 'package:flutter/material.dart';

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F23),
            borderRadius: BorderRadius.circular(34),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'DrawRun',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F1F23),
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 22),
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
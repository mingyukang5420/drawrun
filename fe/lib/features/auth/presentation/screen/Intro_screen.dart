import 'package:flutter/material.dart';

import 'package:running/features/auth/presentation/widgets/auth_button.dart';
import 'package:running/features/auth/presentation/widgets/auth_logo.dart';
import 'package:running/features/auth/presentation/screen/login_screen.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),

              const AuthLogo(),

              const Spacer(flex: 4),

              AuthButton(
                text: '시작하기',
                type: AuthButtonType.primary,
                onPressed: () {
                  // TODO: 회원가입 또는 온보딩 페이지로 이동
                },
              ),

              const SizedBox(height: 14),

              AuthButton(
                text: '로그인',
                type: AuthButtonType.secondary,
                onPressed: () {
                  // TODO: 로그인 페이지로 이동
                },
              ),

              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }
}
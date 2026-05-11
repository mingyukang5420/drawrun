import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:running/routes/route_names.dart';

import 'package:running/features/auth/presentation/widgets/auth_button.dart';
import 'package:running/features/auth/presentation/widgets/auth_logo.dart';

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

              // 앱 로고
              const AuthLogo(),

              const Spacer(flex: 4),

              // 회원가입 이동
              AuthButton(
                text: '시작하기',
                type: AuthButtonType.primary,

                onPressed: () {
                  // 회원가입 화면 이동
                  context.pushNamed(RouteNames.signup);
                },
              ),

              const SizedBox(height: 22),

              // 로그인 이동
              Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  const Text(
                    '이미 계정이 있나요?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      // 로그인 화면 이동
                      context.pushNamed(RouteNames.login);
                    },

                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1C1C1E),
                    ),

                    child: const Text(
                      '로그인',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 52),
            ],
          ),
        ),
      ),
    );
  }
}
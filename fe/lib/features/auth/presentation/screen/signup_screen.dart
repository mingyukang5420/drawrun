import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:running/routes/route_names.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 22,
                  color: Color(0xFF1C1C1E),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                '회원가입',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  color: Color(0xFF1C1C1E),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                '사용자 정보를 입력해주세요',
                style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
              ),

              const SizedBox(height: 32),

              _InputWithAction(
                label: '아이디',
                hintText: '아이디를 입력하세요',
                actionText: '중복확인',
                helperText: '사용 가능한 아이디입니다',
              ),

              const SizedBox(height: 16),

              const _AuthInput(
                label: '닉네임',
                hintText: '닉네임을 입력하세요',
              ),

              const SizedBox(height: 16),

              const _AuthInput(
                label: '이메일',
                hintText: '이메일을 입력하세요',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              const _AuthInput(
                label: '비밀번호',
                hintText: '비밀번호를 입력하세요',
                obscureText: true,
              ),

              const SizedBox(height: 16),

              const _AuthInput(
                label: '비밀번호 확인',
                hintText: '비밀번호를 다시 입력하세요',
                obscureText: true,
              ),

              const SizedBox(height: 16),

              const _AuthInput(
                label: '생년월일',
                hintText: 'YYYY.MM.DD',
                keyboardType: TextInputType.datetime,
              ),

              const SizedBox(height: 16),

              const Text(
                '성별',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _GenderButton(
                      text: '남성',
                      selected: true,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GenderButton(
                      text: '여성',
                      selected: false,
                      onTap: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 회원가입 API 연동 후 접근 권한 설정 화면으로 이동
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF1C1C1E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () => context.pushNamed(RouteNames.login),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '이미 계정이 있으신가요? ',
                        style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                      ),
                      Text(
                        '로그인',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1C1C1E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthInput extends StatelessWidget {
  final String label;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _AuthInput({
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF4F4F4),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _InputWithAction extends StatelessWidget {
  final String label;
  final String hintText;
  final String actionText;
  final String helperText;

  const _InputWithAction({
    required this.label,
    required this.hintText,
    required this.actionText,
    required this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: hintText,
                  filled: true,
                  fillColor: const Color(0xFFF4F4F4),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 58,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(actionText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: Text(
            helperText,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF34C759),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor:
          selected ? const Color(0xFF1C1C1E) : const Color(0xFFF4F4F4),
          foregroundColor:
          selected ? Colors.white : const Color(0xFF9CA3AF),
          side: BorderSide(
            color: selected
                ? const Color(0xFF1C1C1E)
                : const Color(0xFFE5E7EB),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
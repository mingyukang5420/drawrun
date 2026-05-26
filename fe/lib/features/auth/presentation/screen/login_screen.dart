import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:running/features/auth/presentation/auth_provider.dart';
import 'package:running/features/auth/presentation/auth_viewmodel.dart';
import 'package:running/routes/route_names.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 로그인 성공(isLoggedIn=true) 시 메인 화면으로 이동
    ref.listen<AuthState>(authViewModelProvider, (_, next) {
      if (next.isLoggedIn) {
        context.goNamed(RouteNames.main);
      }
    });

    final state = ref.watch(authViewModelProvider);
    final notifier = ref.read(authViewModelProvider.notifier);
    return _LoginBody(state: state, notifier: notifier);
  }
}

class _LoginBody extends StatefulWidget {
  final AuthState state;
  final AuthNotifier notifier;

  const _LoginBody({required this.state, required this.notifier});

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
                '로그인',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  color: Color(0xFF1C1C1E),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                '계속하려면 로그인하세요',
                style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
              ),

              const SizedBox(height: 32),

              _buildInput(
                label: '아이디',
                hintText: '아이디를 입력하세요',
                controller: _idController,
              ),

              const SizedBox(height: 16),

              _buildInput(
                label: '비밀번호',
                hintText: '비밀번호를 입력하세요',
                controller: _passwordController,
                obscureText: true,
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 20,
                child: widget.state.errorMessage != null
                    ? Text(
                        widget.state.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      )
                    : null,
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: widget.state.isLoading
                      ? null
                      : () => widget.notifier.login(
                            loginId: _idController.text.trim(),
                            password: _passwordController.text,
                          ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF1C1C1E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: widget.state.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        '아이디 찾기',
                        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  const Text('|', style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB))),
                  GestureDetector(
                    onTap: () {},
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        '비밀번호 찾기',
                        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  const Text('|', style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB))),
                  GestureDetector(
                    onTap: () => context.pushNamed(RouteNames.signup),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        '회원가입',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1C1C1E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
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
          controller: controller,
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

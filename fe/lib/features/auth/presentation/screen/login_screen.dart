import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/auth/presentation/auth_provider.dart';
import 'package:running/features/auth/presentation/auth_viewmodel.dart';

// 로그인 화면
// TODO: 백엔드 스펙 확정 후 라우팅 연결 및 UI 완성
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authViewModelProvider);
    final notifier = ref.read(authViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: _LoginForm(state: state, notifier: notifier),
    );
  }
}

class _LoginForm extends StatefulWidget {
  final AuthState state;
  final AuthNotifier notifier;

  const _LoginForm({required this.state, required this.notifier});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: '이메일'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: '비밀번호'),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          if (widget.state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.state.isLoading
                  ? null
                  : () => widget.notifier.login(
                        email: _emailController.text.trim(),
                        password: _passwordController.text,
                      ),
              child: widget.state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('로그인'),
            ),
          ),
        ],
      ),
    );
  }
}

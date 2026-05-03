import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/auth/domain/auth_repository.dart';
import 'package:running/shared/network/api_exception.dart';

// 인증 화면의 UI 상태
class AuthState {
  // 로그인·로그아웃 API 호출 중 여부 (로딩 스피너 표시에 사용)
  final bool isLoading;

  // API 오류 발생 시 화면에 표시할 메시지, 없으면 null
  final String? errorMessage;

  // 로그인 성공 여부 (로그인 화면 → 메인 화면 이동 트리거)
  final bool isLoggedIn;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.isLoggedIn = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isLoggedIn,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      );
}

// 인증 상태 관리 Notifier
// state 대입 → 구독 위젯 리빌드 트리거
class AuthNotifier extends Notifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository);

  @override
  AuthState build() => const AuthState();

  // 이메일·비밀번호로 로그인
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.login(email: email, password: password);
      state = state.copyWith(isLoading: false, isLoggedIn: true);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  // 로그아웃 (서버 토큰 무효화 + 로컬 토큰 삭제)
  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      // 서버 오류가 발생해도 로컬 상태는 반드시 초기화
      state = state.copyWith(isLoggedIn: false);
    }
  }
}

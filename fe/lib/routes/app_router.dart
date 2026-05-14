import 'package:go_router/go_router.dart';

import 'package:running/app/main_tab_screen.dart';
import 'package:running/routes/route_names.dart';

import 'package:running/features/auth/presentation/screen/intro_screen.dart';
import 'package:running/features/auth/presentation/screen/login_screen.dart';
import 'package:running/features/auth/presentation/screen/signup_screen.dart';

// true 로 설정하면 인트로/로그인 없이 메인 탭으로 바로 진입 (개발 편의용)
const bool kDevBypassLogin = true;

// 앱 전체 화면 이동 규칙 관리
final GoRouter appRouter = GoRouter(
  initialLocation: kDevBypassLogin ? '/main' : '/intro',

  routes: [
    // 인트로 화면
    GoRoute(
      path: '/intro',
      name: RouteNames.intro,

      builder: (context, state) {
        return const IntroScreen();
      },
    ),

    // 로그인 화면
    GoRoute(
      path: '/login',
      name: RouteNames.login,

      builder: (context, state) {
        return const LoginScreen();
      },
    ),

    // 회원가입 화면
    GoRoute(
      path: '/signup',
      name: RouteNames.signup,

      builder: (context, state) {
        return const SignupScreen();
      },
    ),

    // 메인 탭 화면
    GoRoute(
      path: '/main',
      name: RouteNames.main,

      builder: (context, state) {
        return const MainTabScreen();
      },
    ),
  ],
);
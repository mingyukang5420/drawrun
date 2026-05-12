import 'package:go_router/go_router.dart';

import 'package:running/app/main_tab_screen.dart';
import 'package:running/routes/route_names.dart';

import 'package:running/features/auth/presentation/screen/intro_screen.dart';
import 'package:running/features/auth/presentation/screen/login_screen.dart';
import 'package:running/features/auth/presentation/screen/signup_screen.dart';

// 앱 전체 화면 이동 규칙 관리
final GoRouter appRouter = GoRouter(
  // 앱 시작 시 가장 먼저 보여줄 화면
  initialLocation: '/intro',

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
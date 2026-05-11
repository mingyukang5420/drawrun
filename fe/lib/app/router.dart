import 'package:go_router/go_router.dart';

import 'package:running/features/auth/presentation/screen/intro_screen.dart';

final GoRouter router = GoRouter(
  routes: [
    GoRoute(
      path: '/intro',
      name: 'intro',
      builder: (context, state) => const IntroScreen(),
    ),
  ],
);
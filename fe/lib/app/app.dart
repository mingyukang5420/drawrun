import 'package:flutter/material.dart';

import 'package:running/core/theme/app_theme.dart';
import 'package:running/routes/app_router.dart';

// 앱 전체 설정을 담당하는 클래스
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // 우측 상단 DEBUG 배너 제거
      debugShowCheckedModeBanner: false,

      // 앱 이름
      title: 'running-app',

      // 앱 전체 테마
      theme: AppTheme.theme,

      // go_router 연결
      routerConfig: appRouter,
    );
  }
}
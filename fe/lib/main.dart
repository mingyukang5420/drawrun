import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/app/main_tab_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await FlutterNaverMap().init(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID']!,
    // debugPrint는 kDebugMode일 때만 출력되어 릴리즈 빌드 성능에 영향을 주지 않는다
    onAuthFailed: (ex) {
      debugPrint('네이버 지도 인증 오류: $ex');
    },
  );

  // ProviderScope: 앱 전체에서 Riverpod Provider 를 사용하려면 반드시 루트에 위치해야 한다
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'running-app',
      home: MainTabScreen(),
    );
  }
}
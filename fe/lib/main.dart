import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/app/main_tab_screen.dart';
import 'package:running/core/theme/app_theme.dart';

import 'package:running/shared/network/token_storage.dart';

// TODO: 로그인 화면 구현 전 임시 테스트용 토큰
// 실제 서버에서 발급받은 액세스 토큰으로 교체 후 사용한다
const _kDevToken = 'YOUR_ACCESS_TOKEN_HERE';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  // 로그인 화면 구현 전 테스트용: 토큰을 미리 주입해 인증이 필요한 API 를 사용 가능하게 한다
  TokenStorage.save(_kDevToken);

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'running-app',
      theme: AppTheme.theme,
      home: const MainTabScreen(),
    );
  }
}
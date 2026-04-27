import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

void main() async {
  // 플러터 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  // 네이버 지도 SDK 초기화
  await FlutterNaverMap().init(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID']!,
    onAuthFailed: (ex) {
      print("네이버 지도 인증 오류: $ex");
    },
  );

  runApp(const MyApp());
}

// MyApp 클래스가 없어서 났던 에러를 해결하기 위한 기본 뼈대 코드
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('네이버 지도 테스트')),
        // 여기에 네이버 지도 위젯을 배치합니다.
        body: const NaverMap(),
      ),
    );
  }
}
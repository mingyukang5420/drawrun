import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/app/app.dart';
import 'package:running/routes/app_router.dart';
import 'package:running/shared/network/token_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await FlutterNaverMap().init(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID']!,
    onAuthFailed: (ex) {
      debugPrint('네이버 지도 인증 오류: $ex');
    },
  );

  if (kDevToken != null) {
    TokenStorage.save(kDevToken!);
  }

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
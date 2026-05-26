import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────
// AppTheme
//
// 앱 전역 테마 설정
// · 기본 폰트: Pretendard — 모든 UI 텍스트(버튼·라벨·본문 등)에 자동 적용
// · 로고·메인 타이틀·숫자는 AppTextStyle.suit* 를 명시적으로 사용
//
// 사용법:
//   MaterialApp(theme: AppTheme.theme, ...)
// ─────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
        // Pretendard 를 앱 기본 폰트로 지정
        // — fontFamily 를 여기서만 설정하면 모든 Text 위젯에 자동 적용됨
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A1A)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

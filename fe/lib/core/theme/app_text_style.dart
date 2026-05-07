import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────
// AppTextStyle
//
// 앱 전체에서 공유하는 TextStyle 상수 모음
//
// 폰트 사용 원칙:
//   Pretendard — 모든 UI 텍스트 (본문·라벨·버튼·캡션)
//   SUIT       — 로고·메인 타이틀·숫자 표시
//
// ThemeData(fontFamily: 'Pretendard') 가 전역으로 적용돼 있으므로
// 일반 Text 위젯은 별도 fontFamily 지정 없이도 Pretendard 를 사용한다.
// SUIT 가 필요한 곳에서만 아래 suit* 상수를 명시적으로 지정한다.
// ─────────────────────────────────────────────────────────────────────
class AppTextStyle {
  AppTextStyle._();

  // ── Pretendard: UI 텍스트 ─────────────────────────────────────────

  // 섹션 헤딩 (화면 내 소제목)
  static const heading = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  // 카드·리스트 항목 제목
  static const titleMedium = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // 본문 (일반 설명 텍스트)
  static const body = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  // 버튼 레이블
  static const button = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // 보조 라벨 (아이콘 아래 탭 이름, 태그 등)
  static const label = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // 캡션 (날짜·부연 설명 등 가장 작은 텍스트)
  static const caption = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 10,
    fontWeight: FontWeight.w400,
  );

  // ── SUIT: 로고 · 메인 타이틀 · 숫자 표시 ────────────────────────

  // 앱 로고 / 스플래시 타이틀
  static const suitLogo = TextStyle(
    fontFamily: 'SUIT',
    fontSize: 36,
    fontWeight: FontWeight.w700,
  );

  // 화면 대표 타이틀 (홈·러닝 메인 등)
  static const suitTitle = TextStyle(
    fontFamily: 'SUIT',
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );

  // 러닝 화면 포커스 지표 (시간·거리·페이스 큰 숫자)
  static const suitDisplayLarge = TextStyle(
    fontFamily: 'SUIT',
    fontSize: 64,
    fontWeight: FontWeight.w700,
  );

  // 결과 화면 주요 수치 (완료 거리 등)
  static const suitDisplayMedium = TextStyle(
    fontFamily: 'SUIT',
    fontSize: 44,
    fontWeight: FontWeight.w800,
  );

  // 입력·편집 가능한 제목 숫자 크기
  static const suitDisplaySmall = TextStyle(
    fontFamily: 'SUIT',
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  // 카드·그리드 안의 수치 (칼로리·BPM 등)
  static const suitNumber = TextStyle(
    fontFamily: 'SUIT',
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  // 단위 텍스트 (km, bpm, min/km 옆에 나란히 표시)
  static const suitUnit = TextStyle(
    fontFamily: 'SUIT',
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
}

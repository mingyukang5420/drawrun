import 'package:flutter/material.dart';

// 챌린지 시작 시 노출되는 선택 다이얼로그.
//
// 디자인 시안의 모달:
//   "코스를 골라서 시작할까요?"
//   [   예   ]                 ← 다크 채워진 1차 버튼
//   바로 시작하기                ← 텍스트 형태 보조 액션
//
// 반환값(StartChoice):
//   - pickCourse  : 사용자가 "예" 를 선택 → 호출 측이 코스 선택 화면으로 이동
//   - startNow    : 사용자가 "바로 시작하기" 를 선택 → 호출 측이 러닝 카운트다운으로 이동
//   - null        : 다이얼로그를 배경 탭/뒤로가기로 닫음 → 아무 일 안 함
enum StartChoice { pickCourse, startNow }

class StartChoiceDialog extends StatelessWidget {
  const StartChoiceDialog({super.key});

  // 다이얼로그를 띄우는 헬퍼.
  // 호출자는 `await StartChoiceDialog.show(context)` 로 결과를 받는다.
  static Future<StartChoice?> show(BuildContext context) {
    return showDialog<StartChoice>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => const StartChoiceDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 질문 본문 — 메인 질문 한 줄 + 보조 설명 두 줄.
            const Text(
              '코스를 골라서 시작할까요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '내가 그린 코스를 고르거나\n새로 그릴 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),

            // 1차 버튼 — 코스 선택 화면으로 이동.
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(StartChoice.pickCourse),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '예',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 보조 액션 — 코스 없이 바로 러닝 카운트다운으로.
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(StartChoice.startNow),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: const Text(
                '바로 시작하기',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

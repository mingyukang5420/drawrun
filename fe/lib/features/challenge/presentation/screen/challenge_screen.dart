import 'package:flutter/material.dart';

import 'package:running/features/challenge/data/mock_challenge_data.dart';
import 'package:running/features/challenge/domain/challenge.dart';
import 'package:running/features/challenge/domain/ranking_entry.dart';
import 'package:running/features/challenge/presentation/screen/challenge_course_select_screen.dart';
import 'package:running/features/challenge/presentation/widgets/start_choice_dialog.dart';
import 'package:running/features/running/presentation/screen/running_countdown_screen.dart';

// 챌린지 메인 화면 — 디자인 시안의 "챌린지 시트".
//
// 단일 챌린지(스타 런) 의 도장·이름·참여 수·본인 점수/순위·순위 표를 보여주고,
// 하단의 "시작하기" 버튼을 누르면 코스 선택 / 바로 시작 중 하나로 분기한다.
//
// 본 작업은 디자인/조작만 검증하는 목적이라 서버 연동은 일절 없다.
// 데이터는 mock_challenge_data.dart 에서 가져온다.
class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const challenge = kMockChallenge;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // 시안과 동일하게 회차 라벨 + 시작 D-N 을 헤더에 함께 노출.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              challenge.weekLabel,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(width: 8),
            _DBadge(daysUntilStart: challenge.daysUntilStart),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 상단 — 도장/이름/참가자 수 + 본인 점수·순위 카드.
            _ChallengeHeader(challenge: challenge),

            // 순위 리스트 — 남은 영역을 채우며 스크롤 가능.
            Expanded(
              child: _RankingSection(challenge: challenge),
            ),

            // 하단 — 시작하기 버튼.
            _StartButton(
              onPressed: () => _onStartPressed(context),
            ),
          ],
        ),
      ),
    );
  }

  // 시작하기 버튼 핸들러.
  //
  // 흐름:
  //   1) 다이얼로그 띄움.
  //   2) 결과에 따라:
  //      - pickCourse → 코스 선택 화면 push
  //      - startNow   → RunningCountdownScreen push
  //      - null       → 아무 일 안 함 (사용자가 다이얼로그 닫음)
  Future<void> _onStartPressed(BuildContext context) async {
    final choice = await StartChoiceDialog.show(context);
    if (!context.mounted) return;
    switch (choice) {
      case StartChoice.pickCourse:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ChallengeCourseSelectScreen(),
          ),
        );
        break;
      case StartChoice.startNow:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const RunningCountdownScreen(),
            fullscreenDialog: true,
          ),
        );
        break;
      case null:
        break;
    }
  }
}

// 시작까지 남은 일수를 "D-N" 형태로 표시하는 노란 배지.
// 0 이면 "D-DAY", 음수면 "진행 중" 으로 분기.
class _DBadge extends StatelessWidget {
  final int daysUntilStart;

  const _DBadge({required this.daysUntilStart});

  @override
  Widget build(BuildContext context) {
    String label;
    if (daysUntilStart > 0) {
      label = 'D-$daysUntilStart';
    } else if (daysUntilStart == 0) {
      label = 'D-DAY';
    } else {
      label = '진행 중';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4B0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8A6D00),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 챌린지 헤더 — 도장 아이콘 + 챌린지명 + 참여자 수 + 내 점수/순위 카드.
// ─────────────────────────────────────────────────────────────────────
class _ChallengeHeader extends StatelessWidget {
  final Challenge challenge;

  const _ChallengeHeader({required this.challenge});

  @override
  Widget build(BuildContext context) {
    // 참여자 수에 천 단위 콤마. 간단한 정규식 한 줄로 끝낸다.
    final formattedParticipants = challenge.participantCount
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          // 도장 아이콘 — 노란 별 모양을 큰 사이즈로.
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8C4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFE57F),
                width: 2,
              ),
            ),
            child: Icon(
              challenge.stampIcon,
              size: 56,
              color: const Color(0xFFFFC107),
            ),
          ),
          const SizedBox(height: 10),

          // 도장 한글 라벨 (작은 보조 텍스트).
          Text(
            challenge.stampLabel,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 4),

          // 챌린지 이름 (주요 타이틀).
          Text(
            challenge.title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 4),

          // 참여 인원.
          Text(
            '참여 $formattedParticipants명',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 18),

          // 내 최고 점수 / 현재 순위 카드.
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: '내 최고 점수',
                  value: '${challenge.myBestScore.toStringAsFixed(2)}점',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: '현재 순위',
                  value: '${challenge.myRank}위',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 작은 지표 박스 — "내 최고 점수" / "현재 순위" 같은 한 덩어리.
class _MetricBox extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'SUIT',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 순위 섹션 — 1~3등 + 점선 + 본인 주변 3명.
// ─────────────────────────────────────────────────────────────────────
class _RankingSection extends StatelessWidget {
  final Challenge challenge;

  const _RankingSection({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // 헤더 행 — 회색 보조 텍스트.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '닉네임',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                Text(
                  '점수',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // 1~3등.
          for (final entry in challenge.topRankings) ...[
            _RankingRow(entry: entry),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
          ],

          // 중간 점선 — 1~3등과 본인 주변 사이의 갭 시각화.
          const _SkipDots(),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // 본인 주변 3명.
          for (final entry in challenge.nearMyRankings) ...[
            _RankingRow(entry: entry),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
          ],
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final RankingEntry entry;

  const _RankingRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    // 1~3 위는 살짝 강조해 색상 변경. (단순 메달 효과)
    final isTopThree = entry.rank <= 3;
    // 본인 행은 노란 배경으로 강조.
    final bgColor = entry.isMe ? const Color(0xFFFFF8C4) : Colors.transparent;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontFamily: 'SUIT',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isTopThree
                    ? const Color(0xFFE6B100)
                    : (entry.isMe
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFF6B7280)),
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.username,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: entry.isMe ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF1C1C1E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${entry.score.toStringAsFixed(2)}점',
            style: TextStyle(
              fontFamily: 'SUIT',
              fontSize: 14,
              fontWeight: entry.isMe ? FontWeight.w800 : FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}

// 1~3등과 본인 주변 사이의 점 3개 — 순위 갭 시각화.
class _SkipDots extends StatelessWidget {
  const _SkipDots();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          _Dot(),
          SizedBox(height: 3),
          _Dot(),
          SizedBox(height: 3),
          _Dot(),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        color: Color(0xFFD1D5DB),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 하단 시작하기 버튼 — 노란 채워진 큰 버튼.
// ─────────────────────────────────────────────────────────────────────
class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _StartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD60A),
            foregroundColor: const Color(0xFF1C1C1E),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            '시작하기',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

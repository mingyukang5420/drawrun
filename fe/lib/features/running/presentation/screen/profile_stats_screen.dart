import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/presentation/record_provider.dart';
import 'package:running/features/record/presentation/screen/record_stats_screen.dart';

// 프로필 탭 시 진입하는 내 기록 통계 페이지
// RecordStatsScreen(기간별 차트·합계 카드)을 그대로 재사용하고
// 상단에 챌린지 도전 횟수 강조 카드를 추가한다
class ProfileStatsScreen extends ConsumerWidget {
  const ProfileStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statsViewModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: const Text(
          '내 기록',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 챌린지 도전 현황 강조 카드 ────────────────────────────
            // TODO: 백엔드에서 챌린지 도전 횟수 전용 API 연동 후 분리 예정
            // 현재는 전체 러닝 횟수(totalCount)를 챌린지 도전 횟수로 표시
            _ChallengeHighlightCard(
              distance: state.data.totalDistance,
              challengeCount: state.data.totalCount,
            ),
            const SizedBox(height: 20),

            // ── 기간별 차트·합계 카드 (RecordStatsScreen 재사용) ─────────
            // RecordStatsScreen 내부에 기간 토글이 포함되어 있으므로 별도 토글 불필요
            const RecordStatsScreen(),
          ],
        ),
      ),
    );
  }
}

// 총 달린 거리 + 챌린지 도전 횟수를 나란히 강조하는 상단 카드
class _ChallengeHighlightCard extends StatelessWidget {
  final double distance;
  final int challengeCount;

  const _ChallengeHighlightCard({
    required this.distance,
    required this.challengeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HighlightCell(
              label: '총 달린 거리',
              value: distance.toStringAsFixed(1),
              unit: 'km',
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: Colors.white24,
          ),
          Expanded(
            child: _HighlightCell(
              label: '챌린지 도전',
              value: '$challengeCount',
              unit: '회',
            ),
          ),
        ],
      ),
    );
  }
}

// 강조 카드 내 수치 한 항목
class _HighlightCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _HighlightCell({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

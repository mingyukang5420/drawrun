import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:running/features/auth/presentation/auth_provider.dart';
import 'package:running/features/record/presentation/record_provider.dart';
import 'package:running/features/record/presentation/screen/record_stats_screen.dart';

// 프로필 탭 시 진입하는 내 기록 통계 페이지
// 상단: 프로필 헤더(아바타·이름·아이디) + 검정 하이라이트 카드(달린 거리·챌린지 도전)
// 하단: RecordStatsScreen 재사용 (기간 토글·차트·합계 카드)
class ProfileStatsScreen extends ConsumerWidget {
  const ProfileStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statsViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: '로그아웃',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // 프로필 헤더 — 아바타·이름·아이디 중앙 정렬
          const _ProfileHeader(),

          // 검정 하이라이트 카드 — 달린 거리·챌린지 도전 횟수 강조
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: _HighlightCard(
              distance: state.data.totalDistance,
              // TODO: 백엔드에서 챌린지 도전 횟수 전용 API 연동 후 분리 예정
              challengeCount: state.data.totalCount,
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // 기간별 통계 — 달린 거리·러닝 횟수는 위 카드에서 이미 표시하므로 숨김
          const Expanded(
            child: RecordStatsScreen(showDistanceAndCount: false),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(authViewModelProvider.notifier).logout();
              if (context.mounted) context.go('/intro');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

// ── 프로필 헤더 ─────────────────────────────────────────────────────
// TODO: 백엔드에서 실제 사용자 정보(닉네임·프로필 이미지) 연동 필요
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Color(0xFFE5E7EB),
            child: Icon(Icons.person, color: Color(0xFF9CA3AF), size: 38),
          ),
          SizedBox(height: 12),
          Text(
            '러너',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 4),
          Text(
            '@runner.123',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 검정 하이라이트 카드 ─────────────────────────────────────────────
class _HighlightCard extends StatelessWidget {
  final double distance;
  final int challengeCount;

  const _HighlightCard({
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
          Container(width: 1, height: 48, color: Colors.white24),
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

// 하이라이트 카드 내 수치 한 항목
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:running/features/auth/presentation/auth_provider.dart';
import 'package:running/features/record/domain/record_stats.dart';
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

          // 주간 잔디 위젯 — 최근 12주 활동을 한눈에. period 토글과 무관하게 항상 12주 데이터.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: _WeeklyGrassCard(
              activities: state.data.weeklyActivity,
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // 기간별 통계 — 달린 거리·러닝 횟수 포함 4종 카드
          const Expanded(
            child: RecordStatsScreen(showDistanceAndCount: true),
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
              try {
                await ref.read(authViewModelProvider.notifier).logout();
              } catch (_) {}
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
            '러닝마니아',
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

// ── 주간 잔디 위젯 ──────────────────────────────────────────────────
// 최근 12주(약 3개월) 를 가로 12 칸으로 펼친 GitHub 스타일의 활동 미니 카드.
// 각 칸은 한 주를 의미 — 그 주 안에 한 번이라도 뛰었으면(count > 0) 주황으로 칠한다.
// 거리·횟수와 무관한 단일 색이라 "그 주에 뛰었는가?" 만 한눈에 보여준다.
class _WeeklyGrassCard extends StatelessWidget {
  final List<WeeklyActivity> activities;
  const _WeeklyGrassCard({required this.activities});

  // "한 번이라도 뛰었으면 주황" — 거리/횟수와 무관하게 단일 색.
  // 안 뛴 주는 회색, 뛴 주는 트랙 폴리라인과 같은 톤의 주황으로 통일.
  Color _levelColor(WeeklyActivity a) {
    if (a.count <= 0) return const Color(0xFFE5E7EB);
    return const Color(0xFFFF6B35);
  }

  // 항상 12주 칸을 보장하도록 부족분을 0 활동으로 채워서 돌려준다.
  // - BE 가 12개 정확히 준 경우: 그대로 사용
  // - 첫 사용자/로딩 중/BE 미머지로 빈 리스트로 도착: 오늘 기준 12주를 역산해 전부 회색
  // - 일부만 도착: weekStart 가 일치하는 칸만 실제 데이터, 나머지는 회색
  List<WeeklyActivity> _ensureTwelveWeeks(List<WeeklyActivity> source) {
    if (source.length == 12) return source;

    String fmt(DateTime d) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)}';
    }

    // 오늘이 속한 주의 월요일 = 이번 주의 첫 날.
    // DateTime.weekday: 월=1 ... 일=7 → (weekday - 1) 일 만큼 빼면 그 주 월요일.
    final today = DateTime.now();
    final thisMonday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    final firstMonday = thisMonday.subtract(const Duration(days: 7 * 11));

    final byKey = {for (final a in source) a.weekStart: a};

    return List.generate(12, (i) {
      final monday = firstMonday.add(Duration(days: 7 * i));
      final key = fmt(monday);
      return byKey[key] ??
          WeeklyActivity(weekStart: key, distance: 0, count: 0);
    });
  }

  // 12주 중 첫 번째 / 가운데 / 마지막 주의 월 라벨을 박아 시각적 가이드를 준다.
  // 매주 라벨을 다 박으면 너무 빽빽해져서, 의미 있는 지점만 노출.
  String _monthLabel(int index, WeeklyActivity a) {
    if (index != 0 && index != 6 && index != 11) return '';
    try {
      final date = DateTime.parse(a.weekStart);
      return '${date.month}월';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cells = _ensureTwelveWeeks(activities);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 12주 활동',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < cells.length; i++)
                _GrassCell(
                  monthLabel: _monthLabel(i, cells[i]),
                  color: _levelColor(cells[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrassCell extends StatelessWidget {
  final String monthLabel;
  final Color color;

  const _GrassCell({
    required this.monthLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 14,
          child: Text(
            monthLabel,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 10,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

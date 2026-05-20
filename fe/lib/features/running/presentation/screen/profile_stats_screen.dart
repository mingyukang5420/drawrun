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

          // 검정 하이라이트 카드 — 달린 거리·챌린지 도전 횟수 강조
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: _HighlightCard(
              distance: state.data.totalDistance,
              // TODO: 백엔드에서 챌린지 도전 횟수 전용 API 연동 후 분리 예정
              challengeCount: state.data.totalCount,
            ),
          ),

          // 주간 잔디 위젯 — 최근 12주 활동을 한눈에. period 토글과 무관하게 항상 12주 데이터.
          // 카드 자체는 첫 사용자/로딩 중/BE 미머지 어느 케이스든 항상 노출 —
          // 부족한 주는 위젯 안에서 회색 placeholder 로 채워준다.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _WeeklyGrassCard(
              activities: state.data.weeklyActivity,
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

// ── 주간 잔디 위젯 ──────────────────────────────────────────────────
// 최근 12주(약 3개월) 를 가로 12 칸으로 펼친 GitHub 스타일의 활동 미니 카드.
// 각 칸은 한 주를 의미 — 그 주 안에 한 번이라도 뛰었으면(count > 0) 잔디 색상이 들어간다.
// 거리 합산(km) 로 4단계 색 강도를 결정해 활동량의 차이도 함께 보여준다.
class _WeeklyGrassCard extends StatelessWidget {
  final List<WeeklyActivity> activities;
  const _WeeklyGrassCard({required this.activities});

  // 잔디 셀 한 칸의 4단계 색상 임계값(km, 주 누적).
  //   count == 0 : 회색 (활동 없음)
  //   0 < d <= _t1 : 옅은 초록
  //   _t1 < d <= _t2 : 중간 초록
  //   d > _t2 : 진한 초록
  // 임계값은 일반 러너 주간 거리(3~15km) 를 분위 잡아 둠.
  static const double _t1 = 5.0;
  static const double _t2 = 15.0;

  Color _levelColor(WeeklyActivity a) {
    // "한 번이라도 뛰었으면 잔디" — count 가 0 이면 거리와 무관하게 회색.
    if (a.count <= 0) return const Color(0xFFE5E7EB);
    if (a.distance <= _t1) return const Color(0xFFBBF7D0); // light
    if (a.distance <= _t2) return const Color(0xFF4ADE80); // mid
    return const Color(0xFF15803D); // strong
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
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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

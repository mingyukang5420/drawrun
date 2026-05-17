import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/domain/record_stats.dart';
import 'package:running/features/record/presentation/record_provider.dart';
import 'package:running/features/record/presentation/record_stats_viewmodel.dart';

// 기록 > 통계 화면.
//
// 상단 토글로 기간을 바꾸면 BE 에서 해당 기간의 통계를 받아와
// 차트 + 4종 합계 카드를 갱신한다.
class RecordStatsScreen extends ConsumerWidget {
  // false 로 설정하면 합계 카드 중 달린 거리·러닝 횟수(상단 행)를 숨긴다
  // 프로필 통계 페이지처럼 상단에 별도 카드로 이미 표시된 경우에 사용
  final bool showDistanceAndCount;

  const RecordStatsScreen({super.key, this.showDistanceAndCount = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statsViewModelProvider);
    final notifier = ref.read(statsViewModelProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. 기간 토글 ──────────────────────────────────────────
            _PeriodTabs(
              current: state.period,
              onChanged: (p) => notifier.load(p),
            ),
            const SizedBox(height: 16),

            // ── 2. 차트 영역 ──────────────────────────────────────────
            if (state.isLoading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorMessage != null)
              _ErrorBox(
                message: state.errorMessage!,
                onRetry: () => notifier.load(state.period),
              )
            else
              _ChartCard(stats: state.data),

            const SizedBox(height: 16),

            // ── 3. 합계 카드 ─────────────────────────────────────────
            _SummaryCards(
              stats: state.data,
              showDistanceAndCount: showDistanceAndCount,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 상단 기간 토글 ("주 / 월 / 년 / 전체").
// 시안의 검정 알약(pill) 모양 선택 표시를 단순화한 구현.
// ─────────────────────────────────────────────────────────────────────
class _PeriodTabs extends StatelessWidget {
  final RecordStatsPeriod current;
  final ValueChanged<RecordStatsPeriod> onChanged;

  const _PeriodTabs({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      // 토글 전체를 둘러싸는 옅은 회색 배경.
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: RecordStatsPeriod.values.map((p) {
          final isSelected = p == current;
          return Expanded(
            child: GestureDetector(
              // 같은 옵션을 다시 눌러도 onChanged 가 한 번 호출되어 재조회한다.
              // Pull-to-refresh 가 없는 화면이라 의도된 부수효과.
              onTap: () => onChanged(p),
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  // 선택된 옵션만 검정 배경 + 라운드.
                  color: isSelected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  p.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 차트 카드.
// 상단에 "이번 주 달린 거리 (km)" 같은 보조 텍스트를 두고,
// 그 아래에 막대 그래프를 그린다.
// ─────────────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final RecordStats stats;

  const _ChartCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 라벨 + 기간 — periodLabel 이 비어있으면 라벨만 표기.
          Text(
            stats.periodLabel.isEmpty
                ? '달린 거리 (km)'
                : '${stats.periodLabel} 달린 거리 (km)',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // 막대 그래프 본체. 고정 높이 + 가로는 부모 폭을 꽉 채운다.
          SizedBox(
            height: 140,
            child: _StatsChart(points: stats.chart),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 막대 그래프 본체.
// fl_chart 등의 라이브러리를 쓰지 않고 Flex + Container 로 자체 구현.
// 라이브러리 도입 시 의존성 부담이 크고, 이 정도 단순한 그래프엔 오버킬.
// ─────────────────────────────────────────────────────────────────────
class _StatsChart extends StatelessWidget {
  final List<RecordStatsChartPoint> points;

  const _StatsChart({required this.points});

  @override
  Widget build(BuildContext context) {
    // 데이터가 한 건도 없는 케이스 — 빈 메시지로 대체.
    if (points.isEmpty) {
      return const Center(
        child: Text(
          '데이터가 없습니다',
          style: TextStyle(color: Colors.black38, fontSize: 12),
        ),
      );
    }

    // 막대 높이는 "이 기간 내 최댓값" 을 기준으로 비례 계산한다.
    // 모든 막대가 0 일 때는 높이가 0 이 되어 막대가 안 보일 텐데,
    // 그 경우라도 라벨은 그대로 보여줘야 하므로 maxValue 가 0 이면 1 로 보정.
    final maxValue = points.fold<double>(
      0.0,
          (acc, p) => p.distance > acc ? p.distance : acc,
    );
    final safeMax = maxValue == 0 ? 1.0 : maxValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points.map((p) {
        // 막대 한 칸 = Expanded 로 가로 균등 분할.
        return Expanded(
          child: _ChartBar(
            label: p.label,
            // 0.0 ~ 1.0 사이 비율로 변환 — _ChartBar 내부에서 높이 픽셀로 변환.
            ratio: p.distance / safeMax,
            // 막대 색: 최댓값과 같으면 주황(강조), 아니면 검정.
            // safeMax 보정 때문에 maxValue == 0 인 경우엔 모든 ratio 가 0 이라 색은 안 보임 → OK.
            highlight: maxValue > 0 && p.distance == maxValue,
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 차트의 막대 한 개 + 그 아래 라벨.
// 높이 비율(ratio) 을 외부에서 받아 단순히 그 비율로 막대를 칠한다.
// ─────────────────────────────────────────────────────────────────────
class _ChartBar extends StatelessWidget {
  final String label;
  final double ratio;
  final bool highlight;

  const _ChartBar({
    required this.label,
    required this.ratio,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 막대 — 부모 _StatsChart 의 height(140) 중 라벨 영역(약 20)을 뺀 영역을 비율 차지.
          // ratio == 0 일 때는 1px 정도 가는 띠라도 보여 시각적 연속성을 유지.
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: highlight
                      ? const Color(0xFFFF6B35) // 강조 주황
                      : Colors.black,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          // 라벨 영역.
          SizedBox(
            height: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 4종 합계 카드 (달린 거리 / 러닝 횟수 / 평균 페이스 / 달린 시간).
// 2 x 2 그리드.
// ─────────────────────────────────────────────────────────────────────
class _SummaryCards extends StatelessWidget {
  final RecordStats stats;
  final bool showDistanceAndCount;

  const _SummaryCards({
    required this.stats,
    this.showDistanceAndCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 달린 거리·러닝 횟수 행 — 상위에서 이미 표시 시 숨길 수 있음
        if (showDistanceAndCount) ...[
          Row(
            children: [
              _SummaryCell(
                label: '달린 거리',
                value: stats.totalDistance.toStringAsFixed(1),
                unit: 'km',
              ),
              _SummaryCell(
                label: '러닝 횟수',
                value: '${stats.totalCount}',
                unit: '회',
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            _SummaryCell(label: '평균 페이스', value: stats.avgPace, unit: ''),
            _SummaryCell(label: '달린 시간', value: stats.totalTime, unit: ''),
          ],
        ),
      ],
    );
  }
}

// 합계 카드 한 칸.
class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _SummaryCell({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 라벨 — 가로 균등 분할이라 좁아도 한 줄을 유지하도록 maxLines 1.
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            // 값 + 단위 — 단위가 비어있으면 단위 위젯 자체를 안 그린다.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 에러 메시지 박스 (차트 영역 대신 표기).
class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
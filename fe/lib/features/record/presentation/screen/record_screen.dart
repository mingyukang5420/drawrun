import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/domain/record_stats.dart';
import 'package:running/features/record/domain/record_summary.dart';
import 'package:running/features/record/presentation/record_provider.dart';
import 'package:running/features/record/presentation/screen/record_detail_screen.dart';

// 기록 화면.
//
// 상단에 최근 12주 활동 히트맵을 가장 크게 노출하고,
// 그 바로 아래에 누적 통계(2×2 그리드)를 배치한다.
// 더 아래로 스크롤하면 러닝 기록 목록(무한스크롤)을 확인할 수 있다.
class RecordScreen extends ConsumerStatefulWidget {
  // mypage_screen 에서 initialIndex 를 넘기는 기존 호출을 유지하기 위한 파라미터.
  // 탭이 없어졌으므로 실제로는 사용하지 않는다.
  final int initialIndex;

  const RecordScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 누적 통계와 12주 활동 데이터를 한 번에 가져온다.
    Future.microtask(
      () => ref.read(statsViewModelProvider.notifier).load(RecordStatsPeriod.all),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // 스크롤 끝에서 200px 앞에 도달하면 다음 페이지 로드.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(historyViewModelProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    ref.read(statsViewModelProvider.notifier).load(RecordStatsPeriod.all);
    await ref.read(historyViewModelProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsViewModelProvider);
    final history = ref.watch(historyViewModelProvider);
    final historyNotifier = ref.read(historyViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 페이지 제목
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Text(
                    '기록',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),

              // ── 1. 12주 활동 히트맵 (차트 자리) ────────────────────────
              SliverToBoxAdapter(
                child: _HeatmapCard(
                  weeklyActivity: stats.data.weeklyActivity,
                  isLoading: stats.isLoading,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── 2. 누적 통계 2×2 그리드 ─────────────────────────────
              SliverToBoxAdapter(
                child: _SummaryGrid(
                  data: stats.data,
                  isLoading: stats.isLoading,
                ),
              ),

              // ── 3. 러닝 기록 섹션 헤더 ──────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Text(
                    '러닝 기록',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ),

              // ── 4. 히스토리 리스트 분기 ───────────────────────────────
              if (history.isInitialLoading)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (history.items.isEmpty && history.errorMessage != null)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            history.errorMessage!,
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: historyNotifier.refresh,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (history.items.isEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        '아직 기록된 러닝이 없습니다',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  sliver: SliverList.separated(
                    itemCount: history.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = history.items[i];
                      return _RecordCard(
                        summary: item,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RecordDetailScreen(recordId: item.recordId),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // 추가 페이지 로딩/에러 인디케이터
              if (!history.isInitialLoading && history.items.isNotEmpty) ...[
                if (history.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (history.errorMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              history.errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: historyNotifier.loadMore,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

              SliverSafeArea(
                top: false,
                sliver: const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 12주 활동 히트맵 카드 ─────────────────────────────────────────────────
// 차트가 있던 자리를 차지하는 주요 시각 요소.
class _HeatmapCard extends StatelessWidget {
  final List<WeeklyActivity> weeklyActivity;
  final bool isLoading;

  const _HeatmapCard({
    required this.weeklyActivity,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final activeWeeks = weeklyActivity.where((w) => w.count > 0).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카드 제목 + 활동 주수
          Row(
            children: [
              const Text(
                '최근 12주 활동',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (!isLoading)
                Text(
                  '$activeWeeks / 12주',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 히트맵
          isLoading
              ? const SizedBox(
                  height: 36,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _HeatmapRow(weeks: weeklyActivity),
        ],
      ),
    );
  }
}

// ── 누적 통계 2×2 그리드 ─────────────────────────────────────────────────
// 달린 거리 / 러닝 횟수 / 평균 페이스 / 달린 시간
class _SummaryGrid extends StatelessWidget {
  final RecordStats data;
  final bool isLoading;

  const _SummaryGrid({required this.data, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(height: 120);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _SummaryCell(
                label: '달린 거리',
                value: data.totalDistance.toStringAsFixed(1),
                unit: 'km',
              ),
              _SummaryCell(
                label: '러닝 횟수',
                value: '${data.totalCount}',
                unit: '회',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SummaryCell(label: '평균 페이스', value: data.avgPace, unit: ''),
              _SummaryCell(label: '달린 시간', value: data.totalTime, unit: ''),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 통계 셀 하나 ──────────────────────────────────────────────────────────
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
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 8),
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

// ── 12주 히트맵 ───────────────────────────────────────────────────────────
class _HeatmapRow extends StatelessWidget {
  final List<WeeklyActivity> weeks;

  const _HeatmapRow({required this.weeks});

  // 러닝 횟수에 따른 셀 색상 (4단계)
  Color _colorForCount(int count) {
    if (count == 0) return const Color(0xFFE5E7EB);
    if (count == 1) return const Color(0xFF86EFAC);
    if (count == 2) return const Color(0xFF4ADE80);
    return const Color(0xFF3EAA5B);
  }

  @override
  Widget build(BuildContext context) {
    // 12개 슬롯 확보
    final slots = List<WeeklyActivity?>.generate(
      12,
      (i) => i < weeks.length ? weeks[i] : null,
    );

    // 월이 바뀌는 시점에만 라벨 표기
    final monthLabels = List<String>.filled(12, '');
    String prevMonth = '';
    for (var i = 0; i < 12; i++) {
      final w = slots[i];
      if (w == null || w.weekStart.length < 7) continue;
      final m = int.tryParse(w.weekStart.substring(5, 7))?.toString() ?? '';
      if (m.isNotEmpty && m != prevMonth) {
        monthLabels[i] = '$m월';
        prevMonth = m;
      }
    }

    const gap = 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = (constraints.maxWidth - gap * 11) / 12;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 셀 행
            Row(
              children: List.generate(12, (i) {
                final count = slots[i]?.count ?? 0;
                return Padding(
                  padding: EdgeInsets.only(right: i < 11 ? gap : 0),
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: _colorForCount(count),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 5),
            // 월 라벨 행
            Row(
              children: List.generate(12, (i) {
                return SizedBox(
                  width: cellSize + (i < 11 ? gap : 0),
                  child: Text(
                    monthLabels[i],
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF9CA3AF),
                    ),
                    overflow: TextOverflow.clip,
                    softWrap: false,
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

// ── 러닝 기록 카드 ────────────────────────────────────────────────────────
class _RecordCard extends StatelessWidget {
  final RecordSummary summary;
  final VoidCallback? onTap;

  const _RecordCard({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEFEFEF),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Thumbnail(url: summary.trackImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${summary.distance.toStringAsFixed(1)}km'
                      '   ${summary.runningTime}'
                      '   ${summary.avgPace}/km',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _shortDate(summary.date),
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // "2026. 4. 27." → "04.27"
  String _shortDate(String raw) {
    final parts = raw
        .split(RegExp(r'[.\s]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length < 3) return raw;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(month)}.${two(day)}';
  }
}

// ── 트랙 썸네일 ───────────────────────────────────────────────────────────
class _Thumbnail extends StatelessWidget {
  final String url;

  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 60,
        height: 60,
        child: url.isEmpty
            ? const _ThumbnailPlaceholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ThumbnailPlaceholder(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _ThumbnailPlaceholder();
                },
              ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEDE6),
      child: const Center(
        child: Icon(Icons.show_chart, color: Color(0xFFFF5722), size: 28),
      ),
    );
  }
}

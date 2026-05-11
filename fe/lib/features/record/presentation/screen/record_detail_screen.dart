import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/domain/record_detail.dart';
import 'package:running/features/record/presentation/record_detail_viewmodel.dart';
import 'package:running/features/record/presentation/record_provider.dart';

// 히스토리 상세 화면.
//
// 진입 시 받은 recordId 로 BE 에서 상세 정보를 가져와 표시한다.
// 지도 영역은 trackImageUrl 정적 이미지로만 그려진다 — 인터랙티브 지도는
// "상세 경로 보기" 버튼을 통해 별도 화면(RecordRouteScreen) 에서 진입.
//
// 이번 커밋에서 "상세 경로 보기" 버튼은 임시로 SnackBar 만 띄우게 둔다.
// 다음 커밋(08) 에서 RecordRouteScreen 이 생기면 onPressed 를 Navigator.push 로 바꾼다.
//
// ConsumerWidget 이 아니라 ConsumerStatefulWidget 인 이유:
//   Notifier.build() 시점에는 recordId 를 아직 모르므로, 화면 진입 직후
//   initState 에서 notifier.load(widget.recordId) 를 한 번 호출해 줘야 한다.
//   ConsumerWidget 에는 initState 가 없으므로 Stateful 로 만든다.
class RecordDetailScreen extends ConsumerStatefulWidget {
  final int recordId;

  const RecordDetailScreen({super.key, required this.recordId});

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 프레임이 그려진 다음에 데이터 로드를 트리거한다.
    // initState 안에서 곧바로 ref.read 를 호출해도 큰 문제는 없지만,
    // addPostFrameCallback 으로 한 단계 빼면 위젯 트리가 완전히 구성된 뒤에 호출되어
    // 첫 build() 도중 상태가 바뀌어 예기치 않은 재빌드가 도는 일을 막을 수 있다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(recordDetailViewModelProvider.notifier)
          .load(widget.recordId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordDetailViewModelProvider);
    final notifier = ref.read(recordDetailViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar 제목은 데이터 도착 전에는 빈 문자열, 도착 후엔 title 로 교체.
      appBar: AppBar(
        title: Text(state.data?.title ?? ''),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
      BuildContext context,
      RecordDetailState state,
      RecordDetailNotifier notifier,
      ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: notifier.refresh,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final data = state.data;
    if (data == null) {
      // isLoading 도 false 인데 data 가 null 인 경우 — 이론상 안 나오지만 방어.
      return const Center(child: Text('데이터를 표시할 수 없습니다'));
    }

    // 본문 — 지도(이미지) + 텍스트 영역을 한 번에 세로로 쌓는다.
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. 지도 영역 (trackImageUrl 정적 미리보기) ───────────────
          // 시안의 가로 직사각형 비율(약 16:11) 에 맞춘다.
          // 이미지 자체는 BE 가 만들어 준 경로 스냅샷이라 자체 폴리라인 그리기를 안 해도 된다.
          AspectRatio(
            aspectRatio: 16 / 11,
            child: _TrackPreviewImage(url: data.trackImageUrl),
          ),

          // ── 2. 텍스트 영역 ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 — BE 가 "2026. 4. 27." 형식으로 줌. 그대로 노출.
                // 시안의 "오전 7:32" 시각은 BE 에서 안 주므로 생략.
                Text(
                  data.date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 6),

                // 제목.
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // 메타 요약 텍스트.
                // 시안의 "날짜 · 시작 시각 · 평균 페이스 · 총 거리 · 시간 · 칼로리 · 심박수 · 케이던스"
                // 중 BE 가 주지 않는 시작 시각 / 심박수는 제외하고 표기.
                Text(
                  _metaSummary(data),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // ── 3. 3분할 메트릭 (거리 / 시간 / 페이스) ────────────
                _MetricRow(detail: data),
                const SizedBox(height: 20),

                // ── 4. 상세 경로 보기 버튼 ─────────────────────────
                // 이번 커밋(07)에서는 SnackBar 만 띄운다. 다음 커밋(08)에서
                // 이 onPressed 를 Navigator.push(RecordRouteScreen(...)) 으로 바꾼다.
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('상세 경로 화면은 곧 연결됩니다'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFEFEF),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '상세 경로 보기',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 메타 요약 한 줄 (디자인 시안의 "·" 구분 텍스트).
  String _metaSummary(RecordDetail d) {
    // 항목을 리스트로 모은 뒤 ' · ' 로 join.
    // BE 가 안 주는 항목(시작 시각/심박수) 은 아예 제외.
    final parts = <String>[
      '날짜 ${d.date.trim()}',
      '평균 페이스 ${d.avgPace}',
      '총 거리 ${d.distance.toStringAsFixed(1)}km',
      '시간 ${d.runningTime}',
      '칼로리 ${d.calories}kcal',
      '케이던스 ${d.cadence}spm',
    ];
    return parts.join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────────
// 상단 지도 영역의 정적 이미지 미리보기.
//
// 책임:
//   - trackImageUrl 이 비어있지 않으면 Image.network 로 보여준다.
//   - 로드 실패 / 빈 URL 인 경우 폴백 회색 배경 + 아이콘으로 대체.
//
// 사용자가 이 위젯을 탭하면 어떤 동작도 하지 않는다 — 인터랙션은 아래의
// "상세 경로 보기" 버튼만 담당한다. UX 가 명확해야 사용자가 "이미지를 눌러야 하나?"
// 같은 망설임을 안 한다.
// ─────────────────────────────────────────────────────────────────────
class _TrackPreviewImage extends StatelessWidget {
  final String url;

  const _TrackPreviewImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const _PreviewPlaceholder();
    }
    return Image.network(
      url,
      // 이미지 비율과 컨테이너 비율이 안 맞을 때 cover 로 잘라 채운다.
      // contain 으로 두면 좌우/상하에 회색 띠가 생겨 시안과 멀어진다.
      fit: BoxFit.cover,
      // 로드 실패 시 폴백.
      // 파라미터 3개를 다 쓰지 않으므로 _ 로 버린다 (Dart 3.7+ 권장 표기).
      errorBuilder: (_, _, _) => const _PreviewPlaceholder(),
      // 로딩 중에도 같은 자리에 회색 박스가 보이도록.
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _PreviewPlaceholder(showSpinner: true);
      },
    );
  }
}

// 미리보기 폴백 — 베이지 톤 배경 + 라인차트 아이콘.
// 히스토리 카드 썸네일과 동일한 톤을 써서 둘이 시각적으로 자연스럽게 이어진다.
class _PreviewPlaceholder extends StatelessWidget {
  // 로딩 중 표시 — 스피너를 같이 그릴지 여부.
  final bool showSpinner;

  const _PreviewPlaceholder({this.showSpinner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEDE6),
      child: Center(
        child: showSpinner
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(Icons.show_chart, color: Color(0xFFFF5722), size: 48),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 3분할 메트릭 (거리 / 시간 / 페이스).
// ─────────────────────────────────────────────────────────────────────
class _MetricRow extends StatelessWidget {
  final RecordDetail detail;

  const _MetricRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetricCell(
          label: '거리',
          value: detail.distance.toStringAsFixed(1),
          unit: 'km',
        ),
        _MetricCell(
          label: '시간',
          value: detail.runningTime,
          unit: '',
        ),
        _MetricCell(
          label: '페이스',
          value: detail.avgPace,
          unit: '',
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
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
    );
  }
}
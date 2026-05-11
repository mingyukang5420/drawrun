import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/domain/record_summary.dart';
import 'package:running/features/record/presentation/screen/record_detail_screen.dart';
import 'package:running/features/record/presentation/record_provider.dart';

// 기록 > 히스토리 화면.
//
// 진입 시 첫 페이지를 자동 로드하고, 스크롤이 끝에 닿으면
// 다음 페이지를 이어 받는 무한스크롤을 제공한다.
class RecordHistoryScreen extends ConsumerStatefulWidget {
  const RecordHistoryScreen({super.key});

  @override
  ConsumerState<RecordHistoryScreen> createState() =>
      _RecordHistoryScreenState();
}

class _RecordHistoryScreenState extends ConsumerState<RecordHistoryScreen> {
  // 스크롤 위치를 감시해 끝에 다다랐을 때 loadMore() 를 트리거한다.
  // 화면이 사라지면 dispose 에서 listener 를 떼어 메모리 누수를 방지.
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // 스크롤 변화 콜백.
  // 끝에서 200px 위쪽을 지나가면 다음 페이지 로드 트리거.
  // 200px 여유를 두는 이유: 사용자가 카드를 다 보기 전에 미리 받아 부드러운 UX.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final threshold = position.maxScrollExtent - 200;

    if (position.pixels >= threshold) {
      ref.read(historyViewModelProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyViewModelProvider);
    final notifier = ref.read(historyViewModelProvider.notifier);

    // 화면 전체 로딩 (첫 페이지 진행 중) — 스피너 한 개로 대체.
    if (state.isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 첫 페이지가 비어 있고 에러가 있다 → 빈 화면 + 재시도 버튼.
    if (state.items.isEmpty && state.errorMessage != null) {
      return _ErrorRetry(
        message: state.errorMessage!,
        onRetry: notifier.refresh,
      );
    }

    // 정상이지만 데이터가 0건일 때.
    if (state.items.isEmpty) {
      return const Center(child: Text('저장된 기록이 없습니다'));
    }

    // RefreshIndicator: 사용자가 화면을 아래로 당기면 refresh() 트리거.
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.builder(
        controller: _scrollController,
        // 모든 카드 + (필요 시) 맨 아래 추가 로딩 인디케이터 한 칸.
        // 추가 로딩 중이거나 에러가 발생했을 때만 마지막 슬롯이 살아 있다.
        itemCount:
            state.items.length +
            (state.isLoadingMore || state.errorMessage != null ? 1 : 0),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemBuilder: (context, index) {
          // 마지막 슬롯이면 로딩/에러 표시기를 그린다.
          if (index >= state.items.length) {
            if (state.errorMessage != null) {
              // 추가 로드 실패 — 가벼운 메시지 + 재시도.
              return _LoadMoreError(
                message: state.errorMessage!,
                onRetry: notifier.loadMore,
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RecordCard(
              summary: state.items[index],
              // 탭 시 상세 화면으로 push.
              // recordId 를 인자로 넘겨 상세 화면이 자체적으로 데이터를 가져오게 한다.
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecordDetailScreen(
                      recordId: state.items[index].recordId,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 카드 한 장.
// 왼쪽 썸네일 + 가운데 제목·메트릭 + 오른쪽 날짜 구조.
// ─────────────────────────────────────────────────────────────────────
class _RecordCard extends StatelessWidget {
  final RecordSummary summary;

  // 외부에서 탭 동작을 주입받는다. null 이면 탭이 비활성.
  final VoidCallback? onTap;

  const _RecordCard({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Material → InkWell → 외곽 Container 순서로 감싸는 이유:
    //  - InkWell 의 ripple(파동) 효과를 Material 위에서만 정상적으로 그려진다.
    //  - 클리핑(둥근 모서리) 도 InkWell 의 borderRadius 옵션으로 동기화.
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
              // 트랙 썸네일 — 60x60 정사각.
              _Thumbnail(url: summary.trackImageUrl),
              const SizedBox(width: 12),

              // 가운데 텍스트 영역
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
                    // "5.2km   28:34   5'30''/km" 한 줄 표시.
                    // 글자 간격을 ' · ' 대신 공백 + 길이로 구분 — 디자인 시안과 동일.
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

              // 오른쪽 날짜 — "04.27" 등 짧은 형태로 잘라서 보인다.
              // BE 가 "2026. 4. 27." 로 주므로 끝의 점/공백을 다듬어 "04.27" 로 만든다.
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

  // "2026. 4. 27." → "04.27" 변환.
  // 정규식으로 두 자리 월/일을 뽑아 02d 로 채운다.
  // 변환 실패 시 원본 그대로 노출 (BE 응답 형식이 바뀌어도 화면이 안 깨지도록).
  String _shortDate(String raw) {
    // 점·공백 기준으로 나눠 숫자만 추린다.
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

// 카드 왼쪽의 트랙 썸네일.
// url 이 비어있거나 로드 실패 시 자체 폴백을 그린다.
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
                // 이미지 로드 실패 시 폴백.
                // 네트워크 끊김 / 잘못된 URL 등 모든 케이스 일괄 처리.
                errorBuilder: (_, __, ___) => const _ThumbnailPlaceholder(),
                // 로딩 중에도 같은 자리에서 회색 칸이 보이도록 빈 컨테이너 표기.
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _ThumbnailPlaceholder();
                },
              ),
      ),
    );
  }
}

// 썸네일 placeholder — 시안과 같은 옅은 베이지 + 라인 차트 아이콘.
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

// 첫 페이지 실패 시 화면 가운데 박스.
class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

// 추가 페이지 실패 시 리스트 마지막에 표시되는 작은 배너.
// 이 위젯 자체에 텍스트 버튼을 둬서 사용자가 가볍게 다시 시도하게 한다.
class _LoadMoreError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadMoreError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

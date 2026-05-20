import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/ranking/domain/my_challenge_detail.dart';
import 'package:running/features/ranking/presentation/ranking_provider.dart';
import 'package:running/features/record/presentation/screen/record_route_screen.dart';
import 'package:running/shared/network/api_exception.dart';

// 랭킹 페이지에서 본인 항목을 클릭했을 때 보이는 챌린지 상세 화면.
// 한 번 fetch 해 본인 베스트 기록의 모든 정보를 표시한다.
//
// 미참가 (BE 가 404 RECORD_NOT_FOUND) -> 안내 문구 표시
// 다른 ApiException -> 에러 메시지 + 다시 시도 버튼
class MyChallengeDetailScreen extends ConsumerWidget {
  final int challengeId;

  const MyChallengeDetailScreen({super.key, required this.challengeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(myChallengeDetailProvider(challengeId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '내 챌린지 기록',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1C1C1E)),
      ),
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _buildError(context, ref, err),
        data: (detail) => _buildBody(context, detail),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object err) {
    // BE 가 RECORD_NOT_FOUND 를 던지면 ApiException 으로 도착.
    // 화면에선 그냥 친절한 안내로 변환해 보여 준다.
    final msg = (err is ApiException) ? err.message : '$err';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFF9CA3AF), size: 32),
            const SizedBox(height: 8),
            Text(
              '기록을 불러오지 못했어요.\n$msg',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.invalidate(myChallengeDetailProvider(challengeId)),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MyChallengeDetail detail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 트랙 이미지 (해당 러닝의 트랙 스냅샷)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              detail.trackImageUrl,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 220,
                color: const Color(0xFFE5E7EB),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    color: Color(0xFF9CA3AF), size: 32),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 제목 + 시작 시각
          Text(
            detail.title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDateTime(detail.startedAt),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 20),

          // 순위 + 유사도 강조 카드
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _stat('순위', '${detail.rank}위'),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: const Color(0xFFE5E7EB),
                ),
                Expanded(
                  child: _stat(
                    '유사도',
                    '${detail.similarityScore.toStringAsFixed(2)}%',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 측정값 4개 그리드 (거리 / 시간 / 페이스 / 칼로리)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _stat(
                            '거리', '${detail.distance.toStringAsFixed(2)} km')),
                    Expanded(
                        child: _stat('시간', _formatDuration(detail.runningTime))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _stat('평균 페이스',
                            '${detail.avgPace.toStringAsFixed(2)} 분/km')),
                    Expanded(child: _stat('칼로리', '${detail.calories} kcal')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _stat('케이던스', '${detail.cadence} spm')),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          ),

          // 코스 자세히 보기 — 본인이 뛴 트랙을 풀스크린 네이버 지도 위에 그린다.
          // nodes 가 비어 있으면(BE 응답 이상 케이스) 버튼 자체를 숨겨 사용자가 빈 지도를 보지 않도록.
          if (detail.nodes.isNotEmpty) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecordRouteScreen(
                        nodes: detail.nodes,
                        title: detail.title,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text(
                  '코스 자세히 보기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 작은 통계 한 칸 (라벨 + 값) 유틸.
  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 11,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }
}

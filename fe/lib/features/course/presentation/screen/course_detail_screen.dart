import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/domain/course_draft_detail.dart';
import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseDraftId;

  const CourseDetailScreen({super.key, required this.courseDraftId});

  @override
  ConsumerState<CourseDetailScreen> createState() =>
      _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Provider 인스턴스가 생성된 직후 데이터 로드
    Future.microtask(
      () => ref
          .read(courseDetailProvider.notifier)
          .load(widget.courseDraftId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseDetailProvider);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null || state.detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('코스 상세')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? '데이터를 불러오지 못했습니다',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.read(courseDetailProvider.notifier).reload(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final detail = state.detail!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _DetailAppBar(detail: detail),
          SliverToBoxAdapter(child: _DetailBody(detail: detail)),
        ],
      ),
      bottomNavigationBar: _BottomBar(detail: detail),
    );
  }
}

// ── 앱바 (썸네일 이미지 확장) ───────────────────────────────────────────
class _DetailAppBar extends StatelessWidget {
  final CourseDraftDetail detail;

  const _DetailAppBar({required this.detail});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.white,
      // 상세 API 응답에 trackImageUrl 이 없으므로 항상 placeholder 표시
      flexibleSpace: const FlexibleSpaceBar(
        background: ColoredBox(
          color: Color(0xFFE5E7EB),
          child: Icon(Icons.landscape, color: Color(0xFFD1D5DB), size: 64),
        ),
      ),
    );
  }

}

// ── 메타 정보 + 경로 지도 ───────────────────────────────────────────────
class _DetailBody extends StatelessWidget {
  final CourseDraftDetail detail;

  const _DetailBody({required this.detail});

  // 상세 API 응답에 difficulty/distance/createdAt 이 없으므로 status 만 표시
  static const _statusColor = {
    'READY': Color(0xFF3B82F6),
    'DONE': Color(0xFF10B981),
    'REGISTERED': Color(0xFF8B5CF6),
  };
  static const _statusLabel = {
    'READY': '작성중',
    'DONE': '검증됨',
    'REGISTERED': '등록됨',
  };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor[detail.status];
    final statusLabel = _statusLabel[detail.status];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
              if (statusColor != null && statusLabel != null) ...[
                const SizedBox(width: 8),
                _Badge(label: statusLabel, color: statusColor),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (detail.coordinates.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '경로',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 280,
                child: _RouteMap(detail: detail),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── 경로 지도 (읽기 전용, 제스처 비활성화) ─────────────────────────────
class _RouteMap extends StatefulWidget {
  final CourseDraftDetail detail;

  const _RouteMap({required this.detail});

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  @override
  Widget build(BuildContext context) {
    final coords = widget.detail.coordinates;
    final center = coords[coords.length ~/ 2];

    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(center.latitude, center.longitude),
          zoom: 14,
        ),
        // 상세 화면에서는 지도 조작 불필요 — 경로만 표시
        scrollGesturesEnable: false,
        zoomGesturesEnable: false,
        rotationGesturesEnable: false,
        tiltGesturesEnable: false,
        stopGesturesEnable: false,
      ),
      onMapReady: (controller) async {
        final nCoords = coords
            .map((e) => NLatLng(e.latitude, e.longitude))
            .toList();

        await controller.addOverlay(
          NPolylineOverlay(
            id: 'route',
            coords: nCoords,
            color: const Color(0xFF3B82F6),
            width: 4,
          ),
        );

        // 경로 전체가 보이도록 카메라 자동 조정
        await controller.updateCamera(
          NCameraUpdate.fitBounds(
            NLatLngBounds.from(nCoords),
            padding: const EdgeInsets.all(40),
          ),
        );
      },
    );
  }
}

// ── 하단 버튼 ────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final CourseDraftDetail detail;

  const _BottomBar({required this.detail});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            // 기존 좌표를 에디터에 넘겨 이어서 편집할 수 있게 한다
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CourseEditorScreen(
                  initialNodes: detail.coordinates,
                ),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text(
              '이어서 편집',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/bookmark/presentation/bookmark_list_viewmodel.dart';
import 'package:running/features/bookmark/presentation/bookmark_provider.dart';
import 'package:running/features/course/domain/course.dart';

// 북마크 목록 화면.
//
// 마이페이지 "북마크" 메뉴 / 러닝 메인 화면 + 버튼이 공통으로 push 하는 화면.
// 무한스크롤로 코스 카드를 누적 표시하고, 한 장 탭 시 코스 상세 화면(placeholder)으로 이동한다.
class BookmarkListScreen extends ConsumerStatefulWidget {
  const BookmarkListScreen({super.key});

  @override
  ConsumerState<BookmarkListScreen> createState() => _BookmarkListScreenState();
}

class _BookmarkListScreenState extends ConsumerState<BookmarkListScreen> {
  // 스크롤 위치를 감시해 끝 부근에 가까워지면 다음 페이지를 요청.
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // 스크롤이 바닥에서 300px 이내일 때 다음 페이지 요청.
  // 너무 빡빡하게 잡으면 사용자가 한 번 멈춰야 다음 페이지가 보이고,
  // 너무 헐겁게 잡으면 데이터가 다 안 보이는데 미리 요청한다.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final remaining = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining < 300) {
      // ref.read 인 이유: 콜백 안이라 watch 불필요. 호출만 하면 된다.
      ref.read(bookmarkListProvider.notifier).loadMore();
    }
  }

  // 코스 상세 화면 진입 placeholder.
  //
  // 코스 상세 화면(CourseDetailScreen) 은 다른 팀원이 별도 PR 로 작업 중이다.
  // 머지가 들어오면 아래 SnackBar 를 다음 한 줄로 교체:
  //   Navigator.of(context).push(MaterialPageRoute(
  //     builder: (_) => CourseDetailScreen(courseId: courseId),
  //   ));
  //
  // 그 시점에 이 파일 상단에 CourseDetailScreen import 한 줄도 같이 추가하면 끝.
  void _openCourseDetail(BuildContext context, int courseId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('코스 상세 화면은 별도 작업 중입니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookmarkListProvider);
    final notifier = ref.read(bookmarkListProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('북마크'),
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
      BookmarkListState state,
      BookmarkListNotifier notifier,
      ) {
    if (state.isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.courses.isEmpty) {
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
    if (state.courses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: Color(0xFFD1D5DB),
            ),
            SizedBox(height: 12),
            Text(
              '아직 북마크한 코스가 없습니다',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 4),
            Text(
              '코스를 탐색해 마음에 드는 코스를 추가해 보세요',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    // 정상 본문 — pull-to-refresh 로 감싼 ListView.
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        // courses 개수 + (loadMore 진행 중이면 스피너 한 줄).
        itemCount: state.courses.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          // 마지막 위치에 스피너 한 줄.
          if (index >= state.courses.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final course = state.courses[index];
          return _BookmarkRow(
            course: course,
            onTap: course.id != null
                ? () => _openCourseDetail(context, course.id!)
                : null,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 북마크 목록의 한 줄. 코스 탐색 화면의 카드 모양과 같은 톤으로 맞춘다.
// 시각 일관성을 위해 둥근 모서리 + 그림자 + 좌측 썸네일 + 텍스트 정보.
// ─────────────────────────────────────────────────────────────────────
class _BookmarkRow extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;

  const _BookmarkRow({required this.course, this.onTap});

  // 난이도 색상 / 라벨 — 다른 카드 위젯과 동일한 컨벤션.
  static const _diffColor = {
    'EASY': Color(0xFF27AE60),
    'NORMAL': Color(0xFFE67E22),
    'HARD': Color(0xFFE74C3C),
  };
  static const _diffLabel = {'EASY': '쉬움', 'NORMAL': '보통', 'HARD': '어려움'};

  @override
  Widget build(BuildContext context) {
    final difficulty = course.difficulty ?? '';
    final color = _diffColor[difficulty] ?? const Color(0xFF6B7280);
    final label = _diffLabel[difficulty] ?? difficulty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withOpacity(0.06),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 좌측 정사각형 썸네일.
              _Thumb(url: course.thumbnailUrl),
              const SizedBox(width: 14),
              // 우측 정보.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 코스명 + 난이도 배지.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1C1C1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (course.difficulty != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 지역 · 거리 한 줄.
                    Text(
                      '${course.distance.toStringAsFixed(1)}km'
                          '  ${course.regions.join(' · ')}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 좌측 작은 썸네일.
// 코스 탐색 / 러닝 화면 카드의 썸네일과 같은 톤으로 맞춰 시각 일관성을 유지.
class _Thumb extends StatelessWidget {
  final String? url;

  const _Thumb({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 80,
        height: 80,
        color: const Color(0xFFF0EDE8),
        child: url != null && url!.isNotEmpty
            ? Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _ThumbPlaceholder(),
        )
            : const _ThumbPlaceholder(),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.route, size: 36, color: Color(0xFFFF5722)),
    );
  }
}
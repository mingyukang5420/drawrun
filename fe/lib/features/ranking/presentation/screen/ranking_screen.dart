import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/ranking/domain/challenge_ranking.dart';
import 'package:running/features/ranking/domain/participated_challenge_group.dart';
import 'package:running/features/ranking/domain/rank_entry.dart';
import 'package:running/features/ranking/presentation/participated_viewmodel.dart';
import 'package:running/features/ranking/presentation/ranking_provider.dart';
import 'package:running/features/ranking/presentation/screen/my_challenge_detail_screen.dart';

// 랭킹 탭 메인 화면.
// 참여 챌린지 목록을 받아 시트에 띄우고, 사용자가 고른 챌린지의 Easy/Hard 랭킹을 본문에 그린다.
//
// 진입 시점에 participatedViewModelProvider 가 GET /v1/challenge/participated 를 호출,
// 응답이 도착하면 첫 항목을 _selected 로 자동 지정한다.
class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  // 현재 선택된 챌린지 묶음. participated 응답이 도착하기 전에는 null.
  // 응답 도착 후 첫 빌드에서 첫 항목으로 세팅된다 (build() 안에서 처리).
  ParticipatedChallengeGroup? _selected;

  // 챌린지 선택 바텀시트를 띄운다. 시트가 항목을 고르면 setState 로 본 화면을 다시 그린다.
  void _openChallengePicker(List<ParticipatedChallengeGroup> groups) {
    final selected = _selected;
    if (selected == null) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChallengePickerSheet(
        groups: groups,
        selected: selected,
        onSelect: (g) {
          setState(() => _selected = g);
          // 새 챌린지가 선택되는 순간 두 난이도 랭킹을 동시에 미리 받아 둔다.
          // 그 다음 탭 토글은 캐시 hit 이라 API 호출이 추가로 나가지 않는다.
          _prefetchPair(g);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // 한 챌린지 그룹의 Easy / Hard 두 랭킹을 한꺼번에 prefetch.
  // null 인 ID(해당 난이도 코스가 없는 경우) 는 건너뛴다.
  // build 안에서 호출되어도 빌드 루프가 생기지 않도록 microtask 로 지연 트리거.
  void _prefetchPair(ParticipatedChallengeGroup group) {
    final easyId = group.easyChallengeId;
    final hardId = group.hardChallengeId;
    final notifier = ref.read(challengeRankingViewModelProvider.notifier);
    Future.microtask(() {
      if (easyId != null) notifier.loadIfNeeded(easyId);
      if (hardId != null) notifier.loadIfNeeded(hardId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(participatedViewModelProvider);

    // 챌린지 랭킹 Provider 의 watcher 를 화면 본체에서 유지 — TabBarView 가
    // 보이지 않는 탭 자식을 잠깐 unmount 할 때 watcher 카운트가 0 으로 떨어져
    // autoDispose 가 캐시를 날리는 케이스를 막는다.
    // select 로 dummy 값만 보므로 이 watch 는 추가 rebuild 를 유발하지 않는다.
    ref.watch(challengeRankingViewModelProvider.select((_) => 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '랭킹',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ),
      body: _buildBody(state),
    );
  }

  // 참여 챌린지 응답 상태에 따라 본문을 분기.
  // 1) 로딩 중 → 인디케이터
  // 2) 에러 → 재시도 안내
  // 3) 빈 결과 → "아직 참여한 챌린지가 없습니다"
  // 4) 정상 → 헤더 + 탭 + TabBarView
  Widget _buildBody(ParticipatedListState state) {
    if (state.groups == null && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.groups == null) {
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
                '참여 챌린지를 불러오지 못했어요.\n${state.errorMessage}',
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
                    ref.read(participatedViewModelProvider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final groups = state.groups!;
    if (groups.isEmpty) {
      // 빈 상태 — 참여한 챌린지가 없을 때.
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '아직 참여한 챌린지가 없습니다',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      );
    }

    // 응답 도착 후 첫 빌드에서 _selected 가 비어 있으면 첫 항목으로 세팅.
    // null-assign 이라 한 번만 실행되며, 사용자가 시트로 다른 항목을 골랐다면 그 값을 유지한다.
    // 첫 세팅이 일어난 빌드에서만 prefetch 를 트리거 — 이후 빌드에서는 캐시 hit 으로 무료.
    if (_selected == null) {
      _selected = groups.first;
      _prefetchPair(_selected!);
    }
    final selected = _selected!;

    // DefaultTabController 가 Scaffold 의 body 안쪽 — TabBar 가 본문에 내려와 있는 구조.
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) 챌린지 선택 헤더 — AppBar 바로 아래.
          _ChallengeHeader(
            group: selected,
            onTap: () => _openChallengePicker(groups),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // 2) 난이도 탭 — 헤더 아래.
          //    Material 로 감싸야 TabBar 의 잉크 / 폰트가 정상으로 그려진다.
          const Material(
            color: Colors.white,
            child: TabBar(
              labelColor: Color(0xFF1C1C1E),
              unselectedLabelColor: Color(0xFF9CA3AF),
              labelStyle: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              indicatorColor: Color(0xFF1C1C1E),
              indicatorWeight: 2.5,
              tabs: [
                Tab(text: 'Easy'),
                Tab(text: 'Hard'),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // 3) 두 난이도 본문 — 각 탭이 자기 challengeId 로 ranking API 를 호출.
          Expanded(
            child: TabBarView(
              children: [
                _ChallengeRankingTab(
                  challengeId: selected.easyChallengeId,
                  difficulty: 'EASY',
                ),
                _ChallengeRankingTab(
                  challengeId: selected.hardChallengeId,
                  difficulty: 'HARD',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 챌린지 선택 헤더 ────────────────────────────────────────────────
// AppBar 바로 아래에 자리하는 흰 카드. 탭하면 챌린지 선택 시트가 열린다.
class _ChallengeHeader extends StatelessWidget {
  // BE 가 주는 ParticipatedChallengeGroup 한 항목. title 한 개만 들어 있다.
  final ParticipatedChallengeGroup group;
  final VoidCallback onTap;

  const _ChallengeHeader({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // 자식이 그리지 않는 빈 가장자리에서도 탭이 잡히도록 opaque 로 둔다.
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          children: [
            Expanded(
              // 챌린지 제목 한 줄 — BE 가 주차 라벨까지 포함해 합쳐 보낸다.
              // 길어지면 한 줄에서 잘려 헤더 높이가 흔들리지 않도록 한다.
              child: Text(
                group.title,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // 다른 챌린지로 바꾸기 안내 아이콘
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF9CA3AF),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 챌린지 선택 바텀 시트 ─────────────────────────────────────────────
// 챌린지 단위로 항목을 보여준다. 한 항목을 고르면 두 난이도 탭의 데이터가 갱신된다.
class _ChallengePickerSheet extends StatelessWidget {
  // BE 가 주는 참여 챌린지 묶음 리스트. 빈 리스트일 일은 없다 —
  // 빈 경우 시트 자체를 띄우지 않게 화면 본체에서 분기한다.
  final List<ParticipatedChallengeGroup> groups;

  // 현재 선택된 챌린지 — 이 항목만 굵게 / 진하게 강조.
  final ParticipatedChallengeGroup selected;

  // 시트 항목 탭 콜백.
  final ValueChanged<ParticipatedChallengeGroup> onSelect;

  const _ChallengePickerSheet({
    required this.groups,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 핸들 — 시트 상단 드래그 영역 표식
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '챌린지 선택',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 8),
        // 각 챌린지 항목 — title 한 줄을 그대로 노출.
        // 선택된 항목은 굵게 + 검정, 아니면 가늘게 + 회색.
        // 두 ID 가 nullable 이라 한쪽만 비교하면 (null, null) 끼리도 같다고 잘못 판정될
        // 위험이 있어 title + 두 ID 모두 비교.
        ...groups.map(
          (g) {
            final isSelected = g.title == selected.title &&
                g.easyChallengeId == selected.easyChallengeId &&
                g.hardChallengeId == selected.hardChallengeId;
            return ListTile(
              title: Text(
                g.title,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFF6B7280),
                ),
              ),
              onTap: () => onSelect(g),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── 난이도별 랭킹 탭 본문 ─────────────────────────────────────────────
// 한 챌린지의 한 난이도 랭킹만 그린다.
// challengeRankingViewModelProvider(단일 Notifier) 를 watch 하고,
// state 에서 자기 challengeId 의 캐시 / 로딩 / 에러를 꺼내 분기 표시.
class _ChallengeRankingTab extends ConsumerWidget {
  // 부모가 내려주는 그 탭의 challengeId — Easy 탭이면 group.easyChallengeId, Hard 면 hardChallengeId.
  // 해당 난이도 코스가 없으면 null 로 들어와 빈 상태 분기.
  final int? challengeId;

  // 본 탭이 책임지는 난이도 — 카드 강조색 / 빈 상태 문구 결정에 사용.
  final String difficulty;

  const _ChallengeRankingTab({
    required this.challengeId,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 난이도별 강조색 — EASY 는 초록, HARD 는 검정 계열.
    final accentColor = difficulty == 'EASY'
        ? const Color(0xFF27AE60)
        : const Color(0xFF1C1C1E);

    // 이 챌린지의 본 난이도 코스에 아직 아무도 기록을 남기지 않은 경우.
    // BE 가 그 자리 challengeId 를 null 로 내려 — API 호출 자체가 필요 없다.
    final id = challengeId;
    if (id == null) {
      return _buildEmptyState();
    }

    // 본 탭이 직접 fetch 를 트리거하지 않는다 — 사용자가 시트에서 챌린지를 고른 시점에
    // 부모(_RankingScreenState) 가 두 난이도를 함께 prefetch 한다. 탭 토글은 캐시 hit.
    final state = ref.watch(challengeRankingViewModelProvider);
    final ranking = state.rankingFor(id);
    final error = state.errorFor(id);

    // 캐시가 비어 있는 상태를 한 곳에서 모두 처리.
    // - 에러가 잡혀 있으면 재시도 안내
    // - 그 외에는 모두 로딩 인디케이터 (loading 플래그가 켜지기 전 한 프레임 포함)
    //   이 분기 덕에 prefetch 가 시작되기 직전이나 build 와 microtask 사이의 짧은 순간에
    //   null assertion 이 throw 되어 빨간 에러 박스가 깜빡이는 일이 없다.
    if (ranking == null) {
      if (error != null) {
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
                  '랭킹을 불러오지 못했어요.\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref
                      .read(challengeRankingViewModelProvider.notifier)
                      .refresh(id),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    // 응답은 도착했으나 참가자가 0명인 경우 — 챌린지 코스는 존재하지만 아직 누구도 안 뛴 상태.
    // challengeId 가 null 인 경우와 사용자 입장에서는 같은 의미이므로 동일한 빈 상태로 그린다.
    if (ranking.totalCount == 0) {
      return _buildEmptyState();
    }

    // 정상 — 폴리곤 미리보기(있을 때) + 랭킹 리스트를 세로로 묶어 그린다.
    // 본인 카드 탭으로 상세 화면 진입이 필요하므로 _RankingList 에 challengeId 도 전달.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ranking.polygonImageUrl != null)
          _PolygonPreview(imageUrl: ranking.polygonImageUrl!),
        Expanded(
          child: _RankingList(
            ranking: ranking,
            accentColor: accentColor,
            challengeId: id,
          ),
        ),
      ],
    );
  }

  // "아직 아무도 뛰지 않은 챌린지" 빈 상태 카드.
  // challengeId 자체가 없는 경우와 totalCount 가 0 인 경우 둘 다 같은 모양으로 노출한다.
  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          '아직 아무도 뛰지 않았어요\n첫 번째 러너가 되어 볼까요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ── 챌린지 폴리곤 미리보기 ─────────────────────────────────────────────
// 랭킹 본문 상단에 챌린지 폴리곤 이미지를 표시한다.
// 사용자가 어떤 챌린지 코스를 따라뛰는지 한눈에 확인할 수 있게 한다.
class _PolygonPreview extends StatelessWidget {
  final String imageUrl;

  const _PolygonPreview({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(
            height: 120,
            color: const Color(0xFFF3F4F6),
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF9CA3AF),
              size: 28,
            ),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── 한 챌린지 한 난이도의 랭킹 본문 ───────────────────────────────────
// 상위 5명 + (선택) 점점점 + prevRank + myRank 순으로 카드를 그린다.
//
// 분기 규칙:
//   myRank == null        → top5 만 그린다.
//   myRank.rank <= 5      → 본인이 이미 top5 에 있어 추가 카드 없음.
//   myRank.rank == 6      → top5 다음 줄에 myRank 카드 하나만 (prevRank 는 top5 의 5위와 중복이라 무시).
//   myRank.rank == 7      → top5 → prevRank(6) → myRank(7) 자연 연속, 점점점 없음.
//   myRank.rank >= 8      → top5 → 점점점 → prevRank → myRank.
class _RankingList extends StatelessWidget {
  final ChallengeRanking ranking;
  final Color accentColor;
  // myRank 카드 클릭 시 본인 상세 화면으로 이동할 때 사용.
  final int challengeId;

  const _RankingList({
    required this.ranking,
    required this.accentColor,
    required this.challengeId,
  });

  @override
  Widget build(BuildContext context) {
    final myRank = ranking.myRank;
    final prevRank = ranking.prevRank;

    // top5 자리는 항상 BE 가 준 rankings 리스트 그대로.
    final top5 = ranking.rankings;

    // 본인 카드를 어떻게 표시할지 케이스 분류.
    // 6위면 본인만, 7위면 prevRank + 본인, 8위 이상이면 점점점 + prevRank + 본인.
    final showMyCard = myRank != null && myRank.rank >= 6;
    final showPrevCard =
        myRank != null && myRank.rank >= 7 && prevRank != null;
    final showEllipsis = myRank != null && myRank.rank >= 8;

    // 한 entry 가 본인 카드인지 판정 — top5 안에 본인이 들어가는 케이스(1~5위) 도
    // 같은 헬퍼로 본인 강조 + 탭 가능 처리를 적용한다.
    // BE 의 myRank 와 top5 의 entry 는 같은 Member 의 nickname 을 거쳐 만들어지므로
    // rank + nickname 조합이 일치하면 같은 사람으로 봐도 안전.
    bool isMyEntry(RankEntry e) =>
        myRank != null && e.rank == myRank.rank && e.nickname == myRank.nickname;

    // 본인 카드만 탭으로 본인 상세 화면 진입. top5 / prevRank 카드는 그냥 카드 그대로 둔다.
    Widget wrapTappable(BuildContext context, Widget card) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyChallengeDetailScreen(
                challengeId: challengeId,
              ),
            ),
          );
        },
        child: card,
      );
    }

    return Column(
      children: [
        // 1) 상위 5명 — 항상 리스트로 그린다.
        //    본인이 1~5위면 그 자리 카드를 본인 강조 + 탭 가능으로 바꾼다.
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: top5.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final entry = top5[i];
              final mine = isMyEntry(entry);
              final card = _RankingCard(
                entry: entry,
                accentColor: accentColor,
                isMe: mine,
              );
              return mine ? wrapTappable(context, card) : card;
            },
          ),
        ),

        // 2) 8위 이상일 때만 6위 자리에 들어갈 점 세 개.
        if (showEllipsis)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < 3; i++)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD1D5DB),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),

        // 3) prevRank 카드 — 7위 이상에서만 (6위면 prevRank 가 5위라 top5 와 중복).
        if (showPrevCard)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _RankingCard(
              entry: prevRank,
              accentColor: accentColor,
              isMe: false,
            ),
          ),

        // 4) 내 순위 카드 — 6위 이상에서만 (5위 이내면 top5 에 이미 있음).
        if (showMyCard)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            // myRank 카드 자리만 wrapTappable 로 감싸 본인 상세 화면으로 push.
            child: Builder(
              builder: (context) => wrapTappable(
                context,
                _RankingCard(
                  entry: myRank,
                  accentColor: accentColor,
                  isMe: true,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 랭킹 카드 한 장 ─────────────────────────────────────────────────
// 한 줄의 순위 / 닉네임 / 유사도를 그린다.
// "본인 여부" 는 모델이 아니라 호출 측(_RankingList) 이 전달한다 —
// BE 응답이 자기 자신을 따로 표시해 주지 않기 때문.
class _RankingCard extends StatelessWidget {
  final RankEntry entry;
  final Color accentColor;
  final bool isMe;

  const _RankingCard({
    required this.entry,
    required this.accentColor,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    // 1~3위는 강조색 + 큰 글씨로 차별화.
    final isTop3 = entry.rank <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // 본인 카드는 옅은 강조색 배경 + 테두리로 시각 구분.
        color: isMe ? accentColor.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // 순위 번호 (1~3위는 색상 강조)
          SizedBox(
            width: 32,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: isTop3 ? 20 : 16,
                fontWeight: FontWeight.w800,
                color: isTop3 ? accentColor : const Color(0xFF9CA3AF),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 아바타 — 닉네임 첫 글자.
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE5E7EB),
            child: Text(
              entry.nickname.isNotEmpty ? entry.nickname.substring(0, 1) : '?',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 닉네임 — 본인이면 "(나)" 접미사.
          Expanded(
            child: Text(
              isMe ? '${entry.nickname} (나)' : entry.nickname,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF1C1C1E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 유사도 점수 — 항상 소수점 둘째 자리까지.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.similarityScore.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isTop3 ? accentColor : const Color(0xFF1C1C1E),
                ),
              ),
              const Text(
                '유사도',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

// 랭킹 탭 메인 화면.
// 챌린지 선택 헤더가 위에, 그 아래 Easy / Hard 난이도 탭이 자리한다.
// 챌린지 선택 상태(_selected) 는 본 화면이 들고 있어 두 난이도 탭이 같은 챌린지를 본다.
// TODO: 백엔드 GET /v1/challenge/ranking?challengeId=&difficulty= 연동 후 목업 제거
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  // 현재 선택된 챌린지. 첫 진입 시 "이번 주" 챌린지를 기본 선택한다.
  late _Challenge _selected;

  @override
  void initState() {
    super.initState();
    _selected = _challenges.firstWhere(
      (c) => c.isCurrent,
      orElse: () => _challenges.first,
    );
  }

  // 챌린지 선택 바텀시트를 띄운다. 시트가 항목을 고르면 setState 로 본 화면을 다시 그린다.
  void _openChallengePicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChallengePickerSheet(
        challenges: _challenges,
        selected: _selected,
        onSelect: (c) {
          setState(() => _selected = c);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // DefaultTabController 가 Scaffold 의 body 안쪽에 들어간다 —
    // AppBar.bottom 에 있던 TabBar 도 함께 안쪽으로 내려간다.
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
      body: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) 챌린지 선택 헤더 — AppBar 바로 아래에 붙는다.
            _ChallengeHeader(
              challenge: _selected,
              onTap: _openChallengePicker,
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // 2) 난이도 탭 — 헤더 아래로 내려온다.
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

            // 3) 두 난이도 본문 — 선택된 챌린지의 EASY / HARD 랭킹을 각각 그린다.
            //    Expanded 로 감싸야 TabBarView 가 남은 세로 공간을 채운다.
            Expanded(
              child: TabBarView(
                children: [
                  _ChallengeRankingTab(
                    challenge: _selected,
                    difficulty: 'EASY',
                  ),
                  _ChallengeRankingTab(
                    challenge: _selected,
                    difficulty: 'HARD',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 랭킹 한 줄 데이터 ────────────────────────────────────────────────
class _RankingEntry {
  final int rank;
  final String username;
  final double similarityPct; // 경로 유사도 (%)
  final String duration;       // 달린 시간 (예: "23:14")
  final bool isMe;

  const _RankingEntry({
    required this.rank,
    required this.username,
    required this.similarityPct,
    required this.duration,
    this.isMe = false,
  });
}

// ── 챌린지 목록 ────────────────────────────────────────────────────
// 한 챌린지(주차) 안에 Easy / Hard 두 코스가 함께 묶인다.
// TODO: 백엔드 API 연동 후 제거 — 실제로는 GET /v1/challenge 응답 형태에 맞춰 모델 교체.
class _Challenge {
  // 챌린지 식별자. 목업에선 주차 키('w20') 를 그대로 쓴다.
  final String id;

  // 사용자에게 보여줄 주차 라벨. 예: "2026년 5월 3주차"
  final String weekLabel;

  // 같은 챌린지의 Easy 코스 이름. 예: "다람쥐 런"
  final String easyName;

  // 같은 챌린지의 Hard 코스 이름. 예: "매 런"
  final String hardName;

  // "이번 주" 뱃지 노출용 플래그.
  final bool isCurrent;

  const _Challenge({
    required this.id,
    required this.weekLabel,
    required this.easyName,
    required this.hardName,
    this.isCurrent = false,
  });

  // 선택된 난이도에 해당하는 코스 이름을 돌려준다.
  // 'EASY' / 'HARD' 외 값이 들어오면 안전하게 easyName 으로 폴백.
  String nameOf(String difficulty) =>
      difficulty == 'HARD' ? hardName : easyName;
}

// 챌린지 목록 — 같은 주차의 Easy / Hard 두 코스를 한 항목으로 묶는다.
// 위에서 아래로 최신순(가장 최근 주차가 0번 인덱스).
const List<_Challenge> _challenges = [
  _Challenge(
    id: 'w20',
    weekLabel: '2026년 5월 3주차',
    easyName: '다람쥐 런',
    hardName: '매 런',
    isCurrent: true,
  ),
  _Challenge(
    id: 'w19',
    weekLabel: '2026년 5월 2주차',
    easyName: '여우 런',
    hardName: '늑대 런',
  ),
  _Challenge(
    id: 'w18',
    weekLabel: '2026년 5월 1주차',
    easyName: '토끼 런',
    hardName: '독수리 런',
  ),
  _Challenge(
    id: 'w17',
    weekLabel: '2026년 4월 4주차',
    easyName: '고양이 런',
    hardName: '표범 런',
  ),
];

// 챌린지 ID + 난이도 두 단계로 인덱싱된 목업 랭킹.
// 키: challenge.id (예: 'w20'),  내부 키: 'EASY' | 'HARD'
// TODO: 백엔드 API 연동 시 challengeId + difficulty 쿼리로 top5 + myEntry 형태로 교체.
const Map<String, Map<String, List<_RankingEntry>>> _rankingsByChallenge = {
  'w20': {
    'EASY': [
      _RankingEntry(rank: 1, username: '달리기왕', similarityPct: 97.3, duration: '18:42'),
      _RankingEntry(rank: 2, username: '스피드런', similarityPct: 95.1, duration: '21:05'),
      _RankingEntry(rank: 3, username: '나', similarityPct: 91.8, duration: '24:33', isMe: true),
      _RankingEntry(rank: 4, username: '조깅러버', similarityPct: 88.4, duration: '27:11'),
      _RankingEntry(rank: 5, username: '마라토너', similarityPct: 85.0, duration: '29:54'),
    ],
    'HARD': [
      _RankingEntry(rank: 1, username: '울트라러너', similarityPct: 93.5, duration: '31:07'),
      _RankingEntry(rank: 2, username: '철인', similarityPct: 90.2, duration: '34:22'),
      _RankingEntry(rank: 3, username: '도전자', similarityPct: 85.7, duration: '39:14'),
      _RankingEntry(rank: 4, username: '페이스킵', similarityPct: 81.3, duration: '43:58'),
      _RankingEntry(rank: 5, username: '산악러너', similarityPct: 77.9, duration: '47:30'),
      _RankingEntry(rank: 13, username: '나', similarityPct: 54.2, duration: '01:12:44', isMe: true),
    ],
  },
  // 다른 주차들은 화면 테스트 편의를 위해 빈 리스트로 둔다.
  // 실 BE 연동 시 challengeId 별 진짜 랭킹이 들어온다.
  'w19': {'EASY': <_RankingEntry>[], 'HARD': <_RankingEntry>[]},
  'w18': {'EASY': <_RankingEntry>[], 'HARD': <_RankingEntry>[]},
  'w17': {'EASY': <_RankingEntry>[], 'HARD': <_RankingEntry>[]},
};

// ── 난이도별 랭킹 탭 본문 ─────────────────────────────────────────────
// 한 챌린지의 한 난이도 랭킹만 그린다.
// 챌린지 선택 상태는 부모(_RankingScreenState) 가 들고, 본 위젯은 받은
// 챌린지 + 난이도로 데이터만 꺼내 그리므로 Stateless.
class _ChallengeRankingTab extends StatelessWidget {
  // 부모가 내려주는 현재 챌린지. 두 난이도 탭이 같은 인스턴스를 공유한다.
  final _Challenge challenge;

  // 본 탭이 책임지는 난이도 — 'EASY' 또는 'HARD'.
  final String difficulty;

  const _ChallengeRankingTab({
    required this.challenge,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    // 난이도별 강조색. EASY 는 초록, HARD 는 검정 계열로 옛 색을 그대로 재사용.
    final accentColor = difficulty == 'EASY'
        ? const Color(0xFF27AE60)
        : const Color(0xFF1C1C1E);

    // (챌린지 ID, 난이도) 두 키로 랭킹을 꺼낸다. 키가 없으면 빈 리스트로 폴백.
    final rankings =
        _rankingsByChallenge[challenge.id]?[difficulty] ?? const [];

    // 헤더는 부모가 두 탭 위에서 그리므로 본 위젯은 랭킹 리스트만 반환.
    return _RankingList(rankings: rankings, accentColor: accentColor);
  }
}

// ── 상위 5위 목록 + 내 순위 고정 바 ──────────────────────────────────────
class _RankingList extends StatelessWidget {
  final List<_RankingEntry> rankings;
  final Color accentColor;

  const _RankingList({required this.rankings, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final top5 = rankings.where((e) => e.rank <= 5).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    // 내 순위가 상위 5위 밖인 경우에만 하단에 별도 표시
    final myEntry = rankings.where((e) => e.isMe && e.rank > 5).firstOrNull;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: top5.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                _RankingCard(entry: top5[i], accentColor: accentColor),
          ),
        ),
        if (myEntry != null) ...[
          // 생략된 순위(6위 ~ 내 순위 직전)를 점 세 개로 표현
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _RankingCard(entry: myEntry, accentColor: accentColor),
          ),
        ],
      ],
    );
  }
}

// ── 챌린지 선택 헤더 ────────────────────────────────────────────────
// AppBar 바로 아래에 자리하는 흰 카드. 탭하면 챌린지 선택 시트가 열린다.
class _ChallengeHeader extends StatelessWidget {
  final _Challenge challenge;
  final VoidCallback onTap;

  const _ChallengeHeader({required this.challenge, required this.onTap});

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge.weekLabel,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 한 챌린지의 두 코스를 함께 노출 — 시트 항목과 동일한 컨벤션.
                  // "다람쥐 런 · 매 런" 처럼 EASY → HARD 순서 고정.
                  Text(
                    '${challenge.easyName} · ${challenge.hardName}',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E),
                    ),
                    // 두 줄로 늘어나 헤더 높이가 점프하지 않도록 한 줄에서 자른다.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
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
  final List<_Challenge> challenges;
  final _Challenge selected;
  final ValueChanged<_Challenge> onSelect;

  const _ChallengePickerSheet({
    required this.challenges,
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
        // 각 챌린지 항목 — 위 줄에 주차 라벨(작은 회색), 아래 줄에 두 코스명(큰 검정).
        ...challenges.map(
          (c) {
            // 한 챌린지의 두 코스를 함께 노출 — "다람쥐 런 · 매 런".
            // 가운데 점은 가독성 구분자(EASY → HARD 순서 고정).
            final coursesLabel = '${c.easyName} · ${c.hardName}';

            return ListTile(
              // 위 줄(작은 회색): 주차 라벨
              title: Text(
                c.weekLabel,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              // 아래 줄(큰 검정): 두 코스명. 선택된 항목은 굵게 + 진하게.
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  coursesLabel,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: c.id == selected.id
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: c.id == selected.id
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
              trailing: c.isCurrent
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '이번 주',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
              onTap: () => onSelect(c),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── 랭킹 카드 ────────────────────────────────────────────────────────
class _RankingCard extends StatelessWidget {
  final _RankingEntry entry;
  final Color accentColor;

  const _RankingCard({required this.entry, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.rank <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: entry.isMe
            ? accentColor.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: entry.isMe
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

          // 아바타
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE5E7EB),
            child: Text(
              entry.username.substring(0, 1),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 닉네임 + 달린 시간
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isMe ? '${entry.username} (나)' : entry.username,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight:
                        entry.isMe ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.duration,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),

          // 유사도 점수
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.similarityPct.toStringAsFixed(1)}%',
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

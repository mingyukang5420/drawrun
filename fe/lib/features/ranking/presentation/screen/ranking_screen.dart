import 'package:flutter/material.dart';

// 랭킹 탭 메인 화면
// Easy·Hard 탭으로 나뉘며, 각 탭에서 주차별 챌린지를 선택해 랭킹을 확인한다
// TODO: 백엔드 GET /v1/challenge/ranking?difficulty=EASY&week=2026-W20 연동 후 목업 제거
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
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
        body: const TabBarView(
          children: [
            _ChallengeRankingTab(difficulty: 'EASY'),
            _ChallengeRankingTab(difficulty: 'HARD'),
          ],
        ),
      ),
    );
  }
}

// ── 주차별 챌린지 목업 데이터 ────────────────────────────────────────
// TODO: 백엔드 API 연동 후 제거
class _WeeklyChallenge {
  final String id;
  final String weekLabel; // "2026년 5월 3주차"
  final String name;      // "다람쥐 런"
  final bool isCurrent;

  const _WeeklyChallenge({
    required this.id,
    required this.weekLabel,
    required this.name,
    this.isCurrent = false,
  });

  String get fullTitle => '${weekLabel.substring(6)} $name'; // "5월 3주차 다람쥐 런"
}

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

// 난이도별 목업 주차 목록
const _easyWeeks = [
  _WeeklyChallenge(
    id: 'e-w20', weekLabel: '2026년 5월 3주차', name: '다람쥐 런', isCurrent: true,
  ),
  _WeeklyChallenge(
    id: 'e-w19', weekLabel: '2026년 5월 2주차', name: '여우 런',
  ),
  _WeeklyChallenge(
    id: 'e-w18', weekLabel: '2026년 5월 1주차', name: '토끼 런',
  ),
  _WeeklyChallenge(
    id: 'e-w17', weekLabel: '2026년 4월 4주차', name: '고양이 런',
  ),
];

const _hardWeeks = [
  _WeeklyChallenge(
    id: 'h-w20', weekLabel: '2026년 5월 3주차', name: '매 런', isCurrent: true,
  ),
  _WeeklyChallenge(
    id: 'h-w19', weekLabel: '2026년 5월 2주차', name: '늑대 런',
  ),
  _WeeklyChallenge(
    id: 'h-w18', weekLabel: '2026년 5월 1주차', name: '독수리 런',
  ),
  _WeeklyChallenge(
    id: 'h-w17', weekLabel: '2026년 4월 4주차', name: '표범 런',
  ),
];

// 난이도별 목업 랭킹 데이터 (상위 5위 + 내 순위)
// TODO: 백엔드 API 연동 시 top5 / myEntry 분리해서 받아올 것
const _easyRankings = [
  _RankingEntry(rank: 1, username: '달리기왕', similarityPct: 97.3, duration: '18:42'),
  _RankingEntry(rank: 2, username: '스피드런', similarityPct: 95.1, duration: '21:05'),
  _RankingEntry(rank: 3, username: '나', similarityPct: 91.8, duration: '24:33', isMe: true),
  _RankingEntry(rank: 4, username: '조깅러버', similarityPct: 88.4, duration: '27:11'),
  _RankingEntry(rank: 5, username: '마라토너', similarityPct: 85.0, duration: '29:54'),
];

const _hardRankings = [
  _RankingEntry(rank: 1, username: '울트라러너', similarityPct: 93.5, duration: '31:07'),
  _RankingEntry(rank: 2, username: '철인', similarityPct: 90.2, duration: '34:22'),
  _RankingEntry(rank: 3, username: '도전자', similarityPct: 85.7, duration: '39:14'),
  _RankingEntry(rank: 4, username: '페이스킵', similarityPct: 81.3, duration: '43:58'),
  _RankingEntry(rank: 5, username: '산악러너', similarityPct: 77.9, duration: '47:30'),
  _RankingEntry(rank: 13, username: '나', similarityPct: 54.2, duration: '01:12:44', isMe: true),
];

// ── 난이도별 랭킹 탭 본문 ─────────────────────────────────────────────
class _ChallengeRankingTab extends StatefulWidget {
  final String difficulty; // 'EASY' 또는 'HARD'

  const _ChallengeRankingTab({required this.difficulty});

  @override
  State<_ChallengeRankingTab> createState() => _ChallengeRankingTabState();
}

class _ChallengeRankingTabState extends State<_ChallengeRankingTab> {
  late _WeeklyChallenge _selected;

  List<_WeeklyChallenge> get _weeks =>
      widget.difficulty == 'EASY' ? _easyWeeks : _hardWeeks;

  List<_RankingEntry> get _rankings =>
      widget.difficulty == 'EASY' ? _easyRankings : _hardRankings;

  @override
  void initState() {
    super.initState();
    // 현재 주차 챌린지를 기본 선택
    _selected = _weeks.firstWhere((w) => w.isCurrent, orElse: () => _weeks.first);
  }

  // 주차 선택 바텀 시트
  void _openWeekPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WeekPickerSheet(
        weeks: _weeks,
        selected: _selected,
        onSelect: (w) {
          setState(() => _selected = w);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.difficulty == 'EASY'
        ? const Color(0xFF27AE60)
        : const Color(0xFF1C1C1E);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 주차 선택 헤더 ─────────────────────────────────────────
        GestureDetector(
          onTap: _openWeekPicker,
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
                        _selected.weekLabel,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selected.name,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // 다른 주차로 바꾸기 안내 아이콘
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF9CA3AF),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),

        // ── 랭킹 목록 ─────────────────────────────────────────────
        Expanded(
          child: _RankingList(rankings: _rankings, accentColor: accentColor),
        ),
      ],
    );
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

// ── 주차 선택 바텀 시트 ───────────────────────────────────────────────
class _WeekPickerSheet extends StatelessWidget {
  final List<_WeeklyChallenge> weeks;
  final _WeeklyChallenge selected;
  final ValueChanged<_WeeklyChallenge> onSelect;

  const _WeekPickerSheet({
    required this.weeks,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 핸들
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
          '주차 선택',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 8),
        ...weeks.map(
          (w) => ListTile(
            title: Text(
              '${w.weekLabel}  ${w.name}',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: w.id == selected.id
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: w.id == selected.id
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFF6B7280),
              ),
            ),
            trailing: w.isCurrent
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
            onTap: () => onSelect(w),
          ),
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

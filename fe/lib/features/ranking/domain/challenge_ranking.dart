import 'package:running/features/ranking/domain/rank_entry.dart';

// 한 챌린지(한 난이도) 의 랭킹 화면에 필요한 모든 정보.
//
// BE 의 ChallengeRankingResponse 와 1:1 대응:
//   totalCount / startedAt / endedAt /
//   myRunStartedAt / myRunDistance / myRank / prevRank / rankings
//
// 본 모델은 "현재 보고 있는 한 탭" 한 덩어리만 표현한다 —
// 화면이 Easy / Hard 두 탭을 가지므로 각각 별개 인스턴스로 들고 있다.
class ChallengeRanking {
  // 이 챌린지에 기록을 남긴 전체 참가자 수.
  final int totalCount;

  // 챌린지 시작 / 종료 시각.
  final DateTime startedAt;
  final DateTime endedAt;

  // 내가 이 챌린지에서 실제로 뛴 러닝의 시작 시각 / 거리.
  // 챌린지 미참가 시 둘 다 null.
  final DateTime? myRunStartedAt;
  final double? myRunDistance;

  // 내 순위 — 챌린지 미참가 시 null.
  final RankEntry? myRank;

  // 내 바로 앞 순위 — 내가 6위 이하면 null.
  // 화면에서 점점점 + prevRank 카드를 그릴지는 myRank.rank 값으로 다시 판단한다.
  final RankEntry? prevRank;

  // 상위 5명 랭킹. 항상 길이가 0 또는 5 (BE 가 잘라 줌).
  final List<RankEntry> rankings;

  const ChallengeRanking({
    required this.totalCount,
    required this.startedAt,
    required this.endedAt,
    required this.myRunStartedAt,
    required this.myRunDistance,
    required this.myRank,
    required this.prevRank,
    required this.rankings,
  });

  // BE 응답 envelope.result 를 받아 도메인 객체로 변환.
  factory ChallengeRanking.fromJson(Map<String, dynamic> json) {
    return ChallengeRanking(
      totalCount: json['totalCount'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: DateTime.parse(json['endedAt'] as String),
      myRunStartedAt: _readNullableDateTime(json['myRunStartedAt']),
      myRunDistance: _readNullableDouble(json['myRunDistance']),
      myRank: _readNullableEntry(json['myRank']),
      prevRank: _readNullableEntry(json['prevRank']),
      rankings: (json['rankings'] as List<dynamic>?)
              ?.map((e) => RankEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  // null-safe DateTime 파서. 키가 비었거나 값이 null 이면 null 반환.
  static DateTime? _readNullableDateTime(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw as String);
  }

  // null-safe double 파서. BigDecimal 응답에 대비해 num / String 둘 다 허용.
  static double? _readNullableDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  // null-safe RankEntry 파서. myRank / prevRank 자리는 통째로 null 이 올 수 있어 필요.
  static RankEntry? _readNullableEntry(Object? raw) {
    if (raw == null) return null;
    return RankEntry.fromJson(raw as Map<String, dynamic>);
  }
}

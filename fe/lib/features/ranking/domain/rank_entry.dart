// 랭킹 카드 한 장에 필요한 정보.
//
// BE 의 RankEntryDTO 와 1:1 대응:
//   rank / nickname / similarityScore
//
// 한 응답 안에서 세 자리(top5, myRank, prevRank) 에 같은 모양으로 등장하므로
// 하나의 모델로 통합해 두면 화면 카드 위젯도 한 종류로 끝난다.
class RankEntry {
  // 1부터 시작하는 정수 순위. BE 가 이미 +1 해서 주므로 그대로 사용.
  final int rank;

  // 사용자 닉네임. 본인 항목이면 화면에서 "(나)" 표기를 따로 붙인다.
  final String nickname;

  // 경로 유사도 점수. BE 가 setScale(2, HALF_UP) 로 둘째 자리에서 잘라 주지만
  // FE 도 표시 시 toStringAsFixed(2) 로 한 번 더 안전장치를 건다.
  final double similarityScore;

  const RankEntry({
    required this.rank,
    required this.nickname,
    required this.similarityScore,
  });

  // BE 응답의 한 객체(예: response.result.rankings[0]) 를 받아 변환.
  // similarityScore 는 BigDecimal 이라 num 또는 String 어느 쪽으로도 올 수 있어
  // 둘 다 안전하게 받는다.
  factory RankEntry.fromJson(Map<String, dynamic> json) {
    return RankEntry(
      rank: json['rank'] as int,
      nickname: json['nickname'] as String,
      similarityScore: _readDouble(json['similarityScore']),
    );
  }

  // BigDecimal -> double 변환 헬퍼.
  // null 이 올 일은 없는 자리지만, 방어적으로 0.0 으로 폴백.
  static double _readDouble(Object? raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0.0;
    return 0.0;
  }
}

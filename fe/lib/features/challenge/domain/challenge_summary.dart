// 챌린지 카드 한 장에 필요한 정보.
//
// BE 의 ChallengeSummaryDTO 와 1:1 대응:
//   challengeId / title / polygonImageUrl / totalParticipantCount /
//   myBestSimilarityScore / myBestRank
//
// myBestRank / myBestSimilarityScore 는 사용자가 한 번도 참여한 적이 없으면 null.
// UI 에서 "최고 기록 없음" 으로 표시하는 분기점은 이 두 필드의 null 여부다.
class ChallengeSummary {
  // 챌린지 PK — 향후 랭킹/상세 화면 진입 시 식별자로 사용
  final int challengeId;

  // 챌린지 제목 (BE 컬럼 최대 20자)
  final String title;

  // 챌린지 폴리곤 이미지 외부 URL (BE 컬럼 최대 500자)
  final String polygonImageUrl;

  // 해당 챌린지의 누적 참가자 수 (running_records 에서 distinct member 카운트)
  final int totalParticipantCount;

  // 내 최고 유사도 점수 — 미참여면 null
  final double? myBestSimilarityScore;

  // 내 최고 순위 — 미참여면 null. 카드 하단 "최고 기록 없음" 분기 기준.
  final int? myBestRank;

  const ChallengeSummary({
    required this.challengeId,
    required this.title,
    required this.polygonImageUrl,
    required this.totalParticipantCount,
    required this.myBestSimilarityScore,
    required this.myBestRank,
  });

  // BE 응답 envelope.result.easy / .hard 의 한 항목을 받아 도메인 객체로 변환.
  //
  // BigDecimal 점수는 JSON 으로 내려올 때 num 또는 String 으로 올 수 있어
  // 둘 다 안전하게 받도록 처리한다 (BE 가 setScale(2, HALF_UP) 로 미리 잘라줌).
  factory ChallengeSummary.fromJson(Map<String, dynamic> json) {
    return ChallengeSummary(
      challengeId: json['challengeId'] as int,
      title: json['title'] as String,
      polygonImageUrl: json['polygonImageUrl'] as String,
      totalParticipantCount: json['totalParticipantCount'] as int,
      myBestSimilarityScore: _readNullableDouble(json['myBestSimilarityScore']),
      myBestRank: json['myBestRank'] as int?,
    );
  }

  // BigDecimal -> double 변환 헬퍼.
  // - null 이면 그대로 null
  // - 숫자형이면 double 캐스팅
  // - 문자열형(예: "0.85") 이면 parse
  static double? _readNullableDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}

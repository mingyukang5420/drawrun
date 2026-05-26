import 'package:running/shared/model/lat_lng.dart';

// 랭킹 페이지에서 본인 항목 클릭 시 노출되는 챌린지 상세 정보.
// BE 의 ChallengeResponse.MyChallengeDetailDTO 와 1:1 대응.
class MyChallengeDetail {
  // 본인 베스트 기록의 record PK
  final int recordId;

  // 사용자가 저장한 러닝 제목
  final String title;

  // 러닝 시작 / 종료 시각
  final DateTime startedAt;
  final DateTime endedAt;

  // 러닝 시간 (초)
  final int runningTime;

  // 트랙 거리 (km)
  final double distance;

  // 평균 페이스 (분/km). BE 는 Double 로 저장.
  final double avgPace;

  // 칼로리 (kcal)
  final int calories;

  // 평균 케이던스 (spm)
  final int cadence;

  // 경로 유사도 점수 (0~100)
  final double similarityScore;

  // 챌린지 내 순위 (1-based)
  final int rank;

  // 러닝 트랙 썸네일 이미지 URL
  final String trackImageUrl;

  // 트랙 좌표 시퀀스. 화면에서 지도에 그릴 때 사용.
  final List<LatLng> nodes;

  const MyChallengeDetail({
    required this.recordId,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.runningTime,
    required this.distance,
    required this.avgPace,
    required this.calories,
    required this.cadence,
    required this.similarityScore,
    required this.rank,
    required this.trackImageUrl,
    required this.nodes,
  });

  factory MyChallengeDetail.fromJson(Map<String, dynamic> json) {
    return MyChallengeDetail(
      recordId: json['recordId'] as int,
      title: json['title'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: DateTime.parse(json['endedAt'] as String),
      runningTime: json['runningTime'] as int,
      distance: (json['distance'] as num).toDouble(),
      avgPace: (json['avgPace'] as num).toDouble(),
      calories: json['calories'] as int,
      cadence: json['cadence'] as int,
      similarityScore: _readDouble(json['similarityScore']),
      rank: json['rank'] as int,
      trackImageUrl: json['trackImageUrl'] as String,
      nodes: (json['nodes'] as List<dynamic>)
          .map((e) => LatLng(
                latitude: (e['lat'] as num).toDouble(),
                longitude: (e['lng'] as num).toDouble(),
              ))
          .toList(),
    );
  }

  static double _readDouble(Object? raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0.0;
    return 0.0;
  }
}

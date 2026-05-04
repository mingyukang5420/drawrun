// 서버에 저장된 러닝 기록 도메인 엔티티
// RunningSession 은 진행 중인 세션, RunningRecord 는 서버에 영구 저장된 결과
//
// Dart 3 의 Record 타입과 충돌을 피하기 위해 RunningRecord 로 명명
class RunningRecord {
  // 서버가 부여하는 식별자
  final int id;

  final DateTime startedAt;
  final DateTime endedAt;

  // 총 이동 거리 (km)
  final double distanceKm;

  // 경과 시간 (초)
  final int elapsedSeconds;

  // 평균 페이스 (초/km)
  final double avgPaceSecPerKm;

  // 서버 저장 시각
  final DateTime createdAt;

  const RunningRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.avgPaceSecPerKm,
    required this.createdAt,
  });

  // API 응답 JSON → RunningRecord 변환
  factory RunningRecord.fromJson(Map<String, dynamic> json) => RunningRecord(
        id: json['id'] as int,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        elapsedSeconds: json['elapsedSeconds'] as int,
        avgPaceSecPerKm: (json['avgPaceSecPerKm'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  // 경과 시간 "00:12:34" 형식 변환
  String get elapsedLabel {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  // 평균 페이스 "5'30\"/km" 형식 변환
  String get paceLabel {
    if (avgPaceSecPerKm == 0) return "--'--\"";
    final m = avgPaceSecPerKm ~/ 60;
    final s = (avgPaceSecPerKm % 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"/km";
  }
}

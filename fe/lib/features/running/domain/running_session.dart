import 'package:running/shared/model/lat_lng.dart';

// 한 번의 러닝 세션 도메인 모델 (불변).
// ViewModel.buildSession() 이 finish() 시점의 상태로 만든다.
class RunningSession {
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration elapsed;
  final double distanceKm;
  final double avgPaceSecPerKm;
  final List<LatLng> points;

  // 임시값 (모두 0)
  final int caloriesKcal;
  final double altitudeM;
  final int bpm;
  // TODO: 케이던스 로직 적용
  final int cadenceSpm;

  const RunningSession({
    required this.startedAt,
    required this.endedAt,
    required this.elapsed,
    required this.distanceKm,
    required this.avgPaceSecPerKm,
    required this.points,
    required this.caloriesKcal,
    required this.altitudeM,
    required this.bpm,
    required this.cadenceSpm,
  });
}

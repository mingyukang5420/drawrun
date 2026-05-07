import 'package:running/features/running/data/running_remote_datasource.dart';
import 'package:running/features/running/domain/running_repository.dart';
import 'package:running/features/running/domain/running_session.dart';

// RunningRepository 구현. 도메인 ↔ JSON 매핑 + RemoteDataSource 호출.
// 백엔드 스펙 변경 시 영향이 이 파일과 RemoteDataSource 두 곳에 격리.
class RunningRepositoryImpl implements RunningRepository {
  final RunningRemoteDataSource _remote;

  RunningRepositoryImpl(this._remote);

  @override
  Future<void> save({
    required RunningSession session,
    required String title,
    int? courseId,
    String trackImageUrl = 'tempValue',
  }) async {
    // 매개변수로 받은 메타데이터를 _toJson 에 함께 넘긴다.
    final body = _toJson(
      session: session,
      title: title,
      courseId: courseId,
      trackImageUrl: trackImageUrl,
    );
    await _remote.postSession(body);
  }

// RunningSession + 메타데이터 → BE 가 기대하는 JSON 형태로 변환.
  Map<String, dynamic> _toJson({
    required RunningSession session, // 측정 데이터
    required String title,
    int? courseId,
    required String trackImageUrl,
  }) {
    return {
      'courseId': courseId, // null 가능 (자유 러닝)
      'title': title,
      'distance': session.distanceKm, // 단위: km (도메인과 동일)
      'trackImageUrl': trackImageUrl, // 현재 'tempValue' 고정
      'runningTime': session.elapsed.inSeconds, // 단위: 초
      'avgPace': _toMinPerKm(session.avgPaceSecPerKm),
      'calories': session.caloriesKcal, // 단위: kcal
      'cadence': session.cadenceSpm, // 도메인 모델에 없음. 일단 0 고정
      'startedAt': _formatLocalIso(session.startedAt),
      'endedAt': _formatLocalIso(session.endedAt),
      // BE 키가 nodes / lat / lng. 우리 LatLng.toJson() 은 latitude/longitude 라
      // 그대로 못 쓰고 여기서 직접 변환.
      'nodes': session.points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };
  }

// 로컬 ISO8601 포맷팅.
  String _formatLocalIso(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}'
        'T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  // 분/km 변환.
  // 정책: "초 단위에서 반올림한 뒤 60 으로 나눠 분/km 로 보낸다".
  //
  // distanceKm 이 0 일 때 ViewModel 이 0.0 을 넘겨 주므로 분기 단순화 가능하지만,
  // 안전을 위해 NaN / Infinity 도 0 으로 떨어뜨린다.
  double _toMinPerKm(double secPerKm) {
    if (secPerKm.isNaN || secPerKm.isInfinite || secPerKm <= 0) return 0.0;
    // 초 단위 정수로 반올림 → 60 으로 나눠 분 단위 소수
    final roundedSec = secPerKm.round();
    return roundedSec / 60.0;
  }
}
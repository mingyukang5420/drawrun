import 'package:running/features/running/data/running_remote_datasource.dart';
import 'package:running/features/running/domain/running_repository.dart';
import 'package:running/features/running/domain/running_session.dart';

// RunningRepository 구현. 도메인 ↔ JSON 매핑 + RemoteDataSource 호출.
// 백엔드 스펙 변경 시 영향이 이 파일과 RemoteDataSource 두 곳에 격리.
class RunningRepositoryImpl implements RunningRepository {
  final RunningRemoteDataSource _remote;
  RunningRepositoryImpl(this._remote);

  @override
  Future<void> save(RunningSession session) async {
    final body = _toJson(session);
    await _remote.postSession(body);
  }

  // RunningSession → 서버 전송용 JSON.
  // TODO: 스펙 확정 후 키/형식 수정.
  Map<String, dynamic> _toJson(RunningSession s) {
    return {
      'startedAt': s.startedAt.toIso8601String(),
      'endedAt': s.endedAt.toIso8601String(),
      'elapsedSec': s.elapsed.inSeconds,
      'distanceKm': s.distanceKm,
      'avgPaceSecPerKm': s.avgPaceSecPerKm,
      'points': s.points.map((p) => p.toJson()).toList(),
      'caloriesKcal': s.caloriesKcal,
      'altitudeM': s.altitudeM,
      'bpm': s.bpm,
    };
  }
}
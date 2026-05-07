import 'dart:async';

import 'package:pedometer/pedometer.dart';

// 케이던스(spm = steps per minute) 측정 전용 서비스.
//
// pedometer 패키지의 stepCountStream 은 "OS 부팅 이후 누적 걸음 수" 를 흘려준다.
// 우리가 원하는 건 "현재 페이스" 라서 시간 윈도우(직전 30초) 안의 증가량을
// 분당 단위로 환산해서 내보낸다.
//
// 사용 흐름:
//   1) 러닝 시작 시 service.startListening() → spmStream 구독
//   2) 일시정지 / 재개 시 stop / start 토글
//   3) 종료 시 dispose
class CadenceService {
  // 외부에서 listen 할 출력 스트림.
  // broadcast 로 만들어 여러 곳에서 동시에 listen 해도 안전하게 한다.
  final _output = StreamController<int>.broadcast();
  Stream<int> get spmStream => _output.stream;

  // pedometer 입력 스트림 구독 핸들 (cancel 용).
  StreamSubscription<StepCount>? _input;

  // 직전 30초 동안의 (시점, 누적걸음) 페어를 큐로 보관.
  // 새 이벤트가 들어올 때마다 30초보다 오래된 샘플은 큐 앞에서 잘라내고,
  // 남은 가장 오래된 샘플(≈30초 전) 과 가장 최신 샘플(지금) 의 차이로 spm 계산.
  // "30초 전" 의 기준이 시간 흐름에 따라 같이 움직여야 하므로 (sliding window)
  // 단일 변수가 아니라 List 가 필요하다.
  final List<_Sample> _window = [];

  // 윈도우 길이 — 30초.
  static const _windowSeconds = 30;

  // 측정 시작. 이미 측정 중이면 중복 구독 방지.
  // 권한이 없으면 stepCountStream 이 곧장 onError 로 닫히므로 그 시점에 0 을 한 번 흘려 준다.
  void startListening() {
    if (_input != null) return;

    _input = Pedometer.stepCountStream.listen(
          (event) => _onStepCount(event.steps),
      onError: (_) {
        // 권한 거부 / 센서 미지원 등. spm 0 을 한 번 흘려 UI 가 0 으로 떨어지게.
        _output.add(0);
      },
      cancelOnError: false,
    );
  }

  // 측정 정지 — 일시정지 시 호출. 윈도우는 유지 (재개 시점에 이어서 계산하기 위해).
  Future<void> stopListening() async {
    await _input?.cancel();
    _input = null;
    _window.clear();
  }

  // 새 누적걸음 수가 들어왔을 때.
  void _onStepCount(int totalSteps) {
    final now = DateTime.now();
    // 큐에 새 샘플 추가
    _window.add(_Sample(time: now, steps: totalSteps));
    // 윈도우보다 오래된 샘플 제거 — 큐 앞쪽부터 잘라낸다.
    final cutoff = now.subtract(const Duration(seconds: _windowSeconds));
    _window.removeWhere((s) => s.time.isBefore(cutoff));

    // 샘플이 1개뿐이면 아직 비교할 게 없어 spm 계산 불가. 0 으로 흘림.
    if (_window.length < 2) {
      _output.add(0);
      return;
    }

    // 가장 오래된 샘플과 가장 최신 샘플의 차이로 spm 계산.
    final oldest = _window.first;
    final newest = _window.last;
    final stepsDiff = newest.steps - oldest.steps;
    final secondsDiff =
        newest.time.difference(oldest.time).inMilliseconds / 1000.0;
    if (secondsDiff <= 0) {
      _output.add(0);
      return;
    }
    // 분당 스텝 = (현재 누적걸음 - 과거 누적걸음) / (윈도우 초 길이) * 60
    final spm = (stepsDiff / secondsDiff * 60).round();
    _output.add(spm);
  }

  // 서비스 자체 종료 — Notifier dispose 시 호출.
  // _input 구독 + _output 컨트롤러 둘 다 닫지 않으면 메모리 누수.
  Future<void> dispose() async {
    await _input?.cancel();
    await _output.close();
  }
}

// 윈도우 큐에 들어가는 한 샘플 — 시점과 그 시점의 누적걸음.
class _Sample {
  final DateTime time;
  final int steps;
  const _Sample({required this.time, required this.steps});
}
import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

// 고도 측정 전용 서비스.
//
// 시작 후 5초간 들어온 기압값들을 평균내 baseline 으로 박고,
// 그 이후 측정값과의 차이를 m 단위 상대 고도로 계산해 흘려 준다.
//
//   altitude_relative = 44330 × (1 - (P_now / P_baseline)^(1/5.255))
//     - 양수: 출발지보다 더 높이 올라옴 (기압이 낮아짐)
//     - 음수: 출발지보다 낮은 곳으로 내려옴 (기압이 높아짐)
//     - 0   : 출발지와 같은 높이 (또는 워밍업 중)
//
// 사용 흐름:
//   1) startListening() 첫 호출 → 5초 워밍업 → baseline 확정
//   2) pause/resume → stop/start 토글 (baseline 유지 — 같은 위치니까 그대로 사용)
//   3) clear → reset() 호출로 baseline 폐기 → 다음 startListening 에서 재워밍업
//   4) 종료 시 dispose
class AltitudeService {
  // 외부로 흘려 줄 고도값 스트림. broadcast 라서 여러 곳에서 listen 해도 안전.
  final _output = StreamController<double>.broadcast();
  Stream<double> get altitudeStream => _output.stream;

  // 기압계 raw 스트림 구독 핸들. stopListening 에서 cancel.
  StreamSubscription<BarometerEvent>? _input;

  // 워밍업 시간 — 시작 후 이 기간 동안 모인 압력값을 평균내 baseline 으로 사용.
  // 단일 측정값을 baseline 으로 박으면 첫 1-2초 센서 노이즈가 모든 후속 값에 반영되므로
  // 평균을 내 노이즈를 ±1-2 m 안으로 줄인다.
  static const _warmupSeconds = 5;

  // 워밍업 시작 시각 — startListening 첫 호출 시점.
  DateTime? _warmupStartedAt;

  // 워밍업 동안 모은 기압 샘플들. 5초 지나면 평균 내고 비움.
  final List<double> _warmupSamples = [];

  // 워밍업 후 확정된 baseline 기압 (hPa). null 이면 아직 워밍업 중 또는 reset 직후.
  double? _baselineHpa;

  void startListening() {
    // 이미 구독 중이면 무시 — 중복 listen 방지.
    if (_input != null) return;

    // baseline 이 아직 없으면(첫 시작 또는 reset 직후) 워밍업을 시작한다.
    // baseline 이 이미 있으면(= pause 후 resume) 그대로 이어서 사용 — 출발지 의미 유지.
    if (_baselineHpa == null) {
      _warmupStartedAt = DateTime.now();
      _warmupSamples.clear();
    }

    // sensors_plus 의 barometerEventStream() 은 샘플링 주기를 인자로 받는 stream 함수.
    // BarometerEvent.pressure 가 hPa 단위 기압값.
    // 기압은 빠르게 변하지 않으므로 normalInterval(~200ms) 로 충분 — 배터리도 절약.
    _input = barometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(
          (event) {
        final pressureHpa = event.pressure;

        // 비정상값(0, 음수) 무시.
        if (pressureHpa <= 0) return;

        // baseline 이 정해지지 않았으면 워밍업 단계.
        if (_baselineHpa == null) {
          _warmupSamples.add(pressureHpa);

          final elapsedSec =
              DateTime.now().difference(_warmupStartedAt!).inSeconds;
          if (elapsedSec >= _warmupSeconds && _warmupSamples.isNotEmpty) {
            // 워밍업 종료 — 평균을 baseline 으로 박는다.
            final sum = _warmupSamples.reduce((a, b) => a + b);
            _baselineHpa = sum / _warmupSamples.length;
            _warmupSamples.clear();
          }
          // 워밍업 중 / 워밍업 직후 모두 출발지 기준 0 을 흘려 준다.
          _output.add(0);
          return;
        }

        // baseline 확정 후 — 상대 고도 계산해 흘림.
        final relativeM = _pressureDiffToAltitude(_baselineHpa!, pressureHpa);
        _output.add(relativeM);
      },
      onError: (_) {
        // 기압계 미탑재 / 센서 오류. 0 한 번 흘려 UI 가 0 으로 유지되게.
        _output.add(0);
      },
      cancelOnError: false,
    );
  }

  // 일시정지 시 호출.
  // baseline 은 일부러 유지 — 재개 시점에 같은 baseline 으로 이어서 측정.
  // 사용자가 잠깐 멈췄다 다시 뛰어도 출발지 기준은 그대로여야 의미가 일관됨.
  Future<void> stopListening() async {
    await _input?.cancel();
    _input = null;
  }

  // clear() 등에서 명시적으로 호출 — baseline 폐기 후 다음 시작에서 재워밍업.
  // stopListening 만으론 baseline 이 남아 다음 세션이 옛 baseline 으로 시작되므로
  // "다시 처음으로" 의미가 분명한 시점에만 이 메서드를 호출한다.
  void reset() {
    _baselineHpa = null;
    _warmupSamples.clear();
    _warmupStartedAt = null;
  }

  Future<void> dispose() async {
    await _input?.cancel();
    await _output.close();
  }

  // 두 기압값(baseline vs current) 의 차이를 m 단위 상대 고도로 변환.
  // ISA(International Standard Atmosphere) 기반 변환식.
  //   h = (T₀/L) × (1 − (P/P₀)^(R·L/(g·M)))
  //   - 44330 ≈ T₀/L (표준기온 288.15K ÷ 기온감률 0.0065K/m)
  //   - 5.255  ≈ (g·M)/(R·L) 의 역수
  // P₀ 자리에 baseline 을 넣어 출발지 시점 기준 상대값을 얻는다.
  double _pressureDiffToAltitude(double baselineHpa, double currentHpa) {
    return 44330.0 * (1.0 - pow(currentHpa / baselineHpa, 1.0 / 5.255));
  }
}
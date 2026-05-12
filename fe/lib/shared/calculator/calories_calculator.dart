// 칼로리 계산 전용 헬퍼.
//
// 공식: kcal = MET × 체중(kg) × 시간(hours)
//   - MET (Metabolic Equivalent) 은 운동 강도에 따른 표준 에너지 소비 비율.
//   - 페이스(분/km) 가 빠를수록 MET 이 커진다.
//
// 본 프로젝트는 사용자 몸무게는 입력받지 않고 성별만 받는 구조.
// 따라서 체중은 성별별 한국 성인 평균치를 고정으로 사용한다.
// MVP 단계에선 사용자 성별 데이터도 아직 도입 전이라 남성 평균(70 kg) 고정.
// TODO: 사용자 성별 도입 후 male/female 분기.
class CaloriesCalculator {
  // 한국 성인 남성 평균 체중 (약 71 kg) 의 반올림.
  // 사용자 몸무게는 끝까지 입력받지 않으므로 항상 이 평균값을 사용한다.
  static const double _maleAverageWeightKg = 70.0;

  // 한국 성인 여성 평균 체중.
  // TODO: 사용자 성별 도입 시 male/female 분기에서 사용.
  // ignore: unused_field
  static const double _femaleAverageWeightKg = 58.0;

  // 페이스(초/km) 별 MET 룩업.
  // 표는 ACSM (American College of Sports Medicine) 의 일반 러닝 MET 값 참고.
  static double _metFromPaceSecPerKm(double paceSecPerKm) {
    // 거리/시간이 0 이거나 비현실적 페이스면 운동 안 한 것으로 간주 → 0.
    if (paceSecPerKm <= 0 || paceSecPerKm.isInfinite || paceSecPerKm.isNaN) {
      return 0.0;
    }
    final paceMinPerKm = paceSecPerKm / 60.0;

    // 페이스 구간별 MET (느릴수록 MET 작음).
    if (paceMinPerKm < 4.0) return 14.0; // 매우 빠른 러닝 (~4분/km 이하)
    if (paceMinPerKm < 5.0) return 12.5; // 빠른 러닝
    if (paceMinPerKm < 6.0) return 11.0; // 일반 러닝
    if (paceMinPerKm < 7.0) return 10.0; // 가벼운 러닝
    if (paceMinPerKm < 8.0) return 9.0;  // 느린 러닝
    if (paceMinPerKm < 10.0) return 7.0; // 조깅
    return 5.0;                           // 빠른 걷기 이하
  }

  // 칼로리 계산 — 거리/시간만으로 산출.
  //
  // distanceKm: 누적 거리
  // elapsedSeconds: 누적 경과 초
  // 반환: 누적 칼로리 (kcal, 정수 반올림)
  //
  // 체중은 외부에서 주입받지 않는다 — 사용자 몸무게를 끝까지 안 받는 정책 때문.
  // TODO: 사용자 성별 도입 시 매개변수로 gender 추가, _maleAverageWeightKg /
  //       _femaleAverageWeightKg 분기로 weight 결정.
  static int compute({
    required double distanceKm,
    required int elapsedSeconds,
  }) {
    // 둘 중 하나라도 0 이면 칼로리도 0 — 식이 발산(0 으로 나누기 등) 하지 않게 가드.
    if (distanceKm <= 0 || elapsedSeconds <= 0) return 0;

    // MVP: 성별 정보 없으니 남성 평균 체중 고정.
    // TODO: 사용자 성별 도입 시 분기 — gender == male ? _maleAverageWeightKg : _femaleAverageWeightKg
    final weightKg = _maleAverageWeightKg;

    // 평균 페이스를 기반으로 MET 도출.
    final avgPaceSecPerKm = elapsedSeconds / distanceKm;
    final met = _metFromPaceSecPerKm(avgPaceSecPerKm);

    // 시간 단위는 시(hour) 로 환산.
    final hours = elapsedSeconds / 3600.0;

    // MET × 체중 × 시간.
    final kcal = met * weightKg * hours;
    return kcal.round();
  }
}
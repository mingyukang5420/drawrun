// 챌린지의 코스 선택 화면에 표시할 코스 항목.
//
// 실제 코스 도메인(`features/course/domain/course.dart`) 과는 별개로,
// 챌린지 화면이 디자인 시안과 같은 단순 표현만 필요해 가벼운 별도 모델을 둔다.
// 추후 서버 연동이 들어오면 이 모델을 코스 도메인 모델로 교체하면 된다.
class ChallengeCourse {
  // 코스 식별자 (목 데이터 기준 문자열).
  final String id;

  // 코스 이름 (예: "5K 별 코스 v1").
  final String title;

  // 총 거리 (km).
  final double distanceKm;

  const ChallengeCourse({
    required this.id,
    required this.title,
    required this.distanceKm,
  });
}

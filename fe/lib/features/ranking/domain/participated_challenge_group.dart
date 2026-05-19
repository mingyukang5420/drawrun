// 랭킹 시트에 한 항목으로 보이는 묶음.
//
// BE 의 ParticipatedChallengeGroupDTO 와 1:1 대응:
//   title / easyChallengeId / hardChallengeId
//
// 한 챌린지(주차) 가 보통 Easy / Hard 두 코스를 가지지만, BE 응답에서 한쪽 ID 가
// null 로 올 수 있다 (해당 난이도 코스가 아직 생성되지 않았거나 사용자가
// 그 난이도로는 참여하지 않은 경우 등). 화면은 null 인 난이도 탭을
// "이 챌린지에는 ○○ 코스가 없습니다" 빈 상태로 분기한다.
class ParticipatedChallengeGroup {
  // 사용자가 보는 챌린지 제목. 주차 정보가 이 안에 포함돼 있을 수 있다 (예: "5월 3주차").
  // BE 가 한 줄로 합쳐 주므로 FE 는 그대로 노출.
  final String title;

  // Easy 난이도 코스의 challengeId. 해당 난이도가 없으면 null.
  final int? easyChallengeId;

  // Hard 난이도 코스의 challengeId. 해당 난이도가 없으면 null.
  final int? hardChallengeId;

  const ParticipatedChallengeGroup({
    required this.title,
    required this.easyChallengeId,
    required this.hardChallengeId,
  });

  // 난이도 문자열('EASY' / 'HARD') 을 받아 그 난이도의 challengeId 를 돌려준다.
  // 해당 난이도 코스가 없으면 null — 호출 측이 빈 상태로 분기한다.
  int? challengeIdOf(String difficulty) =>
      difficulty == 'HARD' ? hardChallengeId : easyChallengeId;

  // BE 응답 result 배열의 한 원소를 받아 도메인 객체로 변환.
  // 두 ID 자리는 BE 가 null 을 보낼 수 있으므로 nullable 캐스팅.
  factory ParticipatedChallengeGroup.fromJson(Map<String, dynamic> json) {
    return ParticipatedChallengeGroup(
      title: json['title'] as String,
      easyChallengeId: json['easyChallengeId'] as int?,
      hardChallengeId: json['hardChallengeId'] as int?,
    );
  }
}

// 랭킹 시트에 한 항목으로 보이는 묶음.
//
// BE 의 ParticipatedChallengeGroupDTO 와 1:1 대응:
//   title / easyChallengeId / hardChallengeId
//
// 한 챌린지(주차) 가 Easy / Hard 두 코스를 가지고 두 코스가 별개의 challengeId 로
// 관리되기 때문에, 사용자가 시트에서 한 항목을 고르면 두 ID 가 동시에 따라붙는다.
class ParticipatedChallengeGroup {
  // 사용자가 보는 챌린지 제목. 주차 정보가 이 안에 포함돼 있을 수 있다 (예: "5월 3주차").
  // BE 가 한 줄로 합쳐 주므로 FE 는 그대로 노출.
  final String title;

  // Easy 난이도 코스의 challengeId — Easy 탭이 활성화되면 이 ID 로 랭킹 API 호출.
  final int easyChallengeId;

  // Hard 난이도 코스의 challengeId — Hard 탭이 활성화되면 이 ID 로 랭킹 API 호출.
  final int hardChallengeId;

  const ParticipatedChallengeGroup({
    required this.title,
    required this.easyChallengeId,
    required this.hardChallengeId,
  });

  // 난이도 문자열('EASY' / 'HARD') 을 받아 그 난이도의 challengeId 를 돌려준다.
  // 화면 코드가 매번 if 분기를 쓰지 않도록 모델 내부에 한 곳에 묶어 둔다.
  int challengeIdOf(String difficulty) =>
      difficulty == 'HARD' ? hardChallengeId : easyChallengeId;

  // BE 응답 result 배열의 한 원소를 받아 도메인 객체로 변환.
  // BE 가 보내는 키 이름과 본 모델의 필드 이름이 1:1 매칭된다.
  factory ParticipatedChallengeGroup.fromJson(Map<String, dynamic> json) {
    return ParticipatedChallengeGroup(
      title: json['title'] as String,
      easyChallengeId: json['easyChallengeId'] as int,
      hardChallengeId: json['hardChallengeId'] as int,
    );
  }
}

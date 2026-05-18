import 'package:running/features/challenge/domain/challenge_summary.dart';

// 홈 화면 두 카드(Easy + Hard) 를 한 번의 응답으로 받기 위한 묶음 모델.
//
// BE 가 한 응답에 easy / hard 두 항목을 함께 내려주므로 FE 도 한 객체로 다룬다.
// 두 카드를 분리된 API 로 가져오는 옵션은 없다 (1회 호출).
class ChallengeList {
  final ChallengeSummary easy;
  final ChallengeSummary hard;

  const ChallengeList({
    required this.easy,
    required this.hard,
  });

  // BE 응답 envelope.result 에 해당하는 Map 을 받아 변환.
  factory ChallengeList.fromJson(Map<String, dynamic> json) {
    return ChallengeList(
      easy: ChallengeSummary.fromJson(json['easy'] as Map<String, dynamic>),
      hard: ChallengeSummary.fromJson(json['hard'] as Map<String, dynamic>),
    );
  }
}

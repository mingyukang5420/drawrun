// 챌린지 순위 한 줄.
//
// 목 데이터 전용이라 별다른 변환/직렬화 없음.
class RankingEntry {
  // 순위 (1부터 시작).
  final int rank;

  // 사용자 표시 이름. 닉네임 또는 핸들.
  final String username;

  // 챌린지 점수 — 소수점 둘째 자리까지 표시하므로 double.
  // (별 모양 유사도 같은 점수가 81.32 형태로 내려옴)
  final double score;

  // 본인 행 여부. true 면 화면에서 강조해서 그린다.
  final bool isMe;

  const RankingEntry({
    required this.rank,
    required this.username,
    required this.score,
    this.isMe = false,
  });
}

// 내 코스 목록 한 항목을 표현하는 데이터 모델
// GET /api/v1/editor 응답의 content 배열 원소 하나에 대응한다
class CourseDraft {
  // 에디터에서 저장된 "초안" 코스 식별자 — 러닝 완료 전까지 이 ID로 관리
  final int courseDraftId;

  // 러닝 완료 후 서버가 부여하는 "완성 코스" 식별자
  // 러닝 전(READY 상태)이면 null, 완료 후(DONE/REGISTERED)에는 값이 채워짐
  final int? courseId;

  final String title;
  final String? difficulty; // 'EASY' | 'NORMAL' | 'HARD'
  final String? status; // 'READY' | 'DONE' | 'REGISTERED'
  final double distance;
  final String? trackImageUrl;
  final DateTime? createdAt;

  // 챌린지 코스 목록 API(/api/v1/editor/challenge)에서만 내려오는 필드
  // 일반 내 코스 목록 API(/api/v1/editor)에서는 null
  final String? challengeTitle;   // 소속 챌린지 이름
  final double? similarityScore;  // 챌린지 코스와의 유사도 점수

  const CourseDraft({
    required this.courseDraftId,
    this.courseId,
    required this.title,
    this.difficulty,
    this.status,
    required this.distance,
    this.trackImageUrl,
    this.createdAt,
    this.challengeTitle,
    this.similarityScore,
  });

  factory CourseDraft.fromJson(Map<String, dynamic> json) => CourseDraft(
        courseDraftId: json['courseDraftId'] as int,
        courseId: json['courseId'] as int?,
        title: json['title'] as String,
        difficulty: json['difficulty'] as String?,
        status: json['status'] as String?,
        distance: (json['distance'] as num).toDouble(),
        trackImageUrl: json['trackImageUrl'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        // 챌린지 API에서만 내려오므로 없으면 null 처리
        challengeTitle: json['challengeTitle'] as String?,
        similarityScore: (json['similarityScore'] as num?)?.toDouble(),
      );
}

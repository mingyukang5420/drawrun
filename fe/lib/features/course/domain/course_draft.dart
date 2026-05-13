class CourseDraft {
  final int courseDraftId;
  final int? courseId;
  final String title;
  final String? difficulty;
  final String? status;
  final double distance;
  final String? trackImageUrl;
  final DateTime? createdAt;

  const CourseDraft({
    required this.courseDraftId,
    this.courseId,
    required this.title,
    this.difficulty,
    this.status,
    required this.distance,
    this.trackImageUrl,
    this.createdAt,
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
      );
}

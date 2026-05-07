import 'package:running/shared/model/lat_lng.dart';

// 코스 도메인 엔티티
// GET /v1/courses 응답 구조에 맞춰 필드를 정의한다
class Course {
  // 서버가 부여하는 식별자 (응답 필드: courseId)
  final int? id;

  // 코스 이름 (응답 필드: title)
  final String title;

  // 총 거리 km 단위 (응답 필드: distance)
  final double distance;

  // 코스를 구성하는 GPS 좌표 목록 (목록 API 에는 포함되지 않음)
  final List<LatLng> points;

  // 난이도: EASY / NORMAL / HARD
  final String? difficulty;

  // 코스가 위치한 행정구 목록 (예: ['강남구'])
  final List<String> regions;

  // 사용자가 이 코스를 완주했는지 여부
  final bool isCompleted;

  // 코스 경로 미리보기 이미지 URL
  final String? thumbnailUrl;

  // 서버에서 채워주는 생성 시각
  final DateTime? createdAt;

  // 완주율 0~100 (완주하지 않은 경우 부분 달린 비율)
  final int completionScore;

  const Course({
    this.id,
    required this.title,
    required this.distance,
    this.points = const [],
    this.difficulty,
    this.regions = const [],
    this.isCompleted = false,
    this.thumbnailUrl,
    this.createdAt,
    this.completionScore = 0,
  });

  // GET /v1/courses 응답 아이템 JSON → Course 변환
  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['courseId'] as int?,
        title: json['title'] as String,
        distance: (json['distance'] as num).toDouble(),
        // 목록 API 에는 points 가 없으므로 null 이면 빈 리스트 사용
        points: json['points'] != null
            ? (json['points'] as List<dynamic>)
                .map((e) => LatLng.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
        difficulty: json['difficulty'] as String?,
        regions: json['regions'] != null
            ? List<String>.from(json['regions'] as List)
            : const [],
        isCompleted: json['isCompleted'] as bool? ?? false,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        completionScore: json['completionScore'] as int? ?? 0,
      );

  // POST /api/v1/editor 저장 요청 시 서버로 전송할 JSON
  // coordinates 의 order 는 1부터 시작하는 순서값
  Map<String, dynamic> toJson() => {
        'title': title,
        'coordinates': points.asMap().entries.map((entry) => {
              'lat': entry.value.latitude,
              'lng': entry.value.longitude,
              'order': entry.key + 1,
            }).toList(),
      };
}

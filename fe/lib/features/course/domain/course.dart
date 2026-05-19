import 'package:running/shared/model/lat_lng.dart';

enum CourseStatus {
  all,        // 필터 전용 (ALL — 서버 파라미터)
  ready,      // 작성중 (에디터 저장, 미주행)
  done,       // 검증됨 (주행 완료, 미등록)
  registered; // 등록됨 (정식 코스 등록 완료)

  // 서버 응답 문자열 → enum 변환 (null/미지원이면 null)
  static CourseStatus? fromString(String? value) => switch (value) {
        'READY' => ready,
        'DONE' => done,
        'REGISTERED' => registered,
        _ => null,
      };

  // API 쿼리 파라미터로 전달할 문자열
  String get queryValue => switch (this) {
        all => 'ALL',
        ready => 'READY',
        done => 'DONE',
        registered => 'REGISTERED',
      };

  String get label => switch (this) {
        all => '전체',
        ready => '작성중',
        done => '검증됨',
        registered => '등록됨',
      };
}

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

  // 코스 상태: READY | DONE | REGISTERED (내 코스 관리 API 에서 반환)
  final CourseStatus? status;

  // 챌린지 저장 시 POST /api/v1/editor 바디에 포함할 챌린지 ID
  // null 이면 toJson 에서 필드 자체를 생략 (일반 코스 저장과 동일)
  final int? challengeId;

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
    this.status,
    this.challengeId,
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
        status: CourseStatus.fromString(json['status'] as String?),
      );

  // POST /api/v1/editor 저장 요청 시 서버로 전송할 JSON
  // coordinates 의 order 는 1부터 시작하는 순서값
  // challengeId 가 있을 때만 포함 — 누락 시 서버 403 원인이 되므로 조건부 삽입
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'title': title,
      'coordinates': points.asMap().entries.map((entry) => {
            'lat': entry.value.latitude,
            'lng': entry.value.longitude,
            'order': entry.key + 1,
          }).toList(),
    };
    if (challengeId != null) json['challengeId'] = challengeId;
    return json;
  }
}

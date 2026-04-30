import 'package:running/shared/model/lat_lng.dart';

// 코스 도메인 엔티티
// 프레임워크(Dio, flutter_naver_map)에 의존하지 않는 순수 데이터 클래스
class Course {
  // 서버가 부여하는 식별자. 저장 전에는 null
  final int? id;

  // 코스 이름
  final String name;

  // 총 거리 (km 단위)
  final double distanceKm;

  // 코스를 구성하는 GPS 좌표 목록
  final List<LatLng> points;

  // 서버에서 채워주는 생성 시각
  final DateTime? createdAt;

  const Course({
    this.id,
    required this.name,
    required this.distanceKm,
    required this.points,
    this.createdAt,
  });

  // API 응답 JSON → Course 변환
  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as int?,
        name: json['name'] as String,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        points: (json['points'] as List<dynamic>)
            .map((e) => LatLng.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  // 서버 전송용 JSON 변환 결과 (id, createdAt 은 서버가 채우므로 제외)
  Map<String, dynamic> toJson() => {
        'name': name,
        'distanceKm': distanceKm,
        'points': points.map((e) => e.toJson()).toList(),
      };
}

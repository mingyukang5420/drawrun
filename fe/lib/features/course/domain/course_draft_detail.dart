import 'package:running/shared/model/lat_lng.dart';

class CourseDraftDetail {
  final int courseDraftId;
  final int? courseId;
  final String title;
  final String? difficulty;
  final String? status;
  final double distance;
  final String? trackImageUrl;
  final DateTime? createdAt;
  final List<LatLng> coordinates;

  const CourseDraftDetail({
    required this.courseDraftId,
    this.courseId,
    required this.title,
    this.difficulty,
    this.status,
    required this.distance,
    this.trackImageUrl,
    this.createdAt,
    this.coordinates = const [],
  });

  factory CourseDraftDetail.fromJson(Map<String, dynamic> json) {
    final rawCoords = json['coordinates'] as List<dynamic>? ?? [];
    final sorted = List<Map<String, dynamic>>.from(rawCoords)
      ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    return CourseDraftDetail(
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
      coordinates: sorted
          .map((e) => LatLng(
                latitude: (e['lat'] as num).toDouble(),
                longitude: (e['lng'] as num).toDouble(),
              ))
          .toList(),
    );
  }
}

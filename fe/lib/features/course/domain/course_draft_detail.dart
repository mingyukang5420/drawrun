import 'package:running/shared/model/lat_lng.dart';

// GET /api/v1/editor/{editorId} 응답 result 필드에 대응하는 모델
// 실제 응답: { editorId, title, status, coordinates:[{lat,lng}] }
// 목록 API(CourseDraft)와 달리 difficulty/distance/trackImageUrl/createdAt 이 없다
class CourseDraftDetail {
  final int editorId;
  final String title;
  final String? status;
  final List<LatLng> coordinates;

  const CourseDraftDetail({
    required this.editorId,
    required this.title,
    this.status,
    this.coordinates = const [],
  });

  factory CourseDraftDetail.fromJson(Map<String, dynamic> json) {
    final rawCoords = json['coordinates'] as List<dynamic>? ?? [];
    return CourseDraftDetail(
      // 서버에 따라 editorId 또는 courseDraftId 로 내려올 수 있음
      editorId: json['editorId'] as int? ?? json['courseDraftId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      status: json['status'] as String?,
      // 서버가 이미 순서대로 반환하므로 order 정렬 불필요
      coordinates: rawCoords
          .map((e) => LatLng(
                latitude: (e['lat'] as num).toDouble(),
                longitude: (e['lng'] as num).toDouble(),
              ))
          .toList(),
    );
  }
}

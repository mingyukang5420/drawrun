// 서버에서 내려주는 주행 가능 도로 엔티티
// OpenStreetMap 의 Way 데이터를 기반으로 하며, 지도에 경로 후보를 표시할 때 사용
class Way {
  // OpenStreetMap 고유 식별자
  final int osmId;

  // 도로 종류 (예: footway, residential, path)
  final String highway;

  // 도로 이름 (없을 수 있음)
  final String? name;

  // 도로 형상 정보 (GeoJSON 형식)
  final WayGeom geom;

  const Way({
    required this.osmId,
    required this.highway,
    required this.name,
    required this.geom,
  });

  // API 응답 JSON → Way 변환
  factory Way.fromJson(Map<String, dynamic> json) => Way(
        osmId: json['osmId'] as int,
        highway: json['highway'] as String,
        name: json['name'] as String?,
        geom: WayGeom.fromJson(json['geom'] as Map<String, dynamic>),
      );
}

// GeoJSON Geometry 모델
// type 은 보통 "LineString", coordinates 는 [[경도, 위도], ...] 형식
class WayGeom {
  // GeoJSON 도형 타입 (예: "LineString")
  final String type;

  // 좌표 배열. 각 원소는 [경도, 위도] 순서의 double 리스트
  final List<List<double>> coordinates;

  const WayGeom({required this.type, required this.coordinates});

  factory WayGeom.fromJson(Map<String, dynamic> json) => WayGeom(
        type: json['type'] as String,
        coordinates: (json['coordinates'] as List<dynamic>)
            .map(
              (point) => (point as List<dynamic>)
                  .map((v) => (v as num).toDouble())
                  .toList(),
            )
            .toList(),
      );
}

// 러닝과 코스 도메인이 공통으로 사용하는 위도/경도 모델.
// 지도 SDK(flutter_naver_map)에 의존하지 않도록 별도 클래스로 분리.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng({required this.latitude, required this.longitude});

  // JSON 응답에서 LatLng 생성
  factory LatLng.fromJson(Map<String, dynamic> json) => LatLng(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  // 서버로 전송할 JSON 변환 결과
  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

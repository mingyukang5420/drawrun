import 'package:running/shared/model/lat_lng.dart';

// GET /api/v1/run/start 응답 모델.
//
// 서버 응답의 envelope 부분(isSuccess/code/message) 은
// RunningRepositoryImpl 에서 벗겨낸 뒤 'result' 안쪽만 이 모델로 변환한다.
//
//   응답 result 예시:
//   { "nodes": null }                    // 자유 러닝
//   { "nodes": [{lat, lng}, ...] }       // 코스 / 드래프트 러닝
class RunStartResponse {
  // 자유 러닝이면 빈 리스트, 코스/드래프트 러닝이면 GPS 노드 배열.
  // null 응답도 빈 리스트로 정규화해 사용처에서 null 체크 부담을 없앤다.
  final List<LatLng> nodes;

  const RunStartResponse({
    required this.nodes,
  });

  // 'result' 객체의 Map 을 받아 모델로 변환.
  // nodes 가 키 자체로 없거나 null 이면 빈 리스트로 떨어뜨린다.
  factory RunStartResponse.fromResultJson(Map<String, dynamic> result) {
    final rawNodes = result['nodes'] as List<dynamic>? ?? const [];
    return RunStartResponse(
      // BE 가 lat / lng 키를 쓰므로 우리 LatLng.fromJson(latitude/longitude) 가 아닌
      // 직접 변환을 사용. course 도메인의 노드 변환 정책과 같은 형태.
      nodes: rawNodes
          .map((e) => LatLng(
        latitude:
        ((e as Map<String, dynamic>)['lat'] as num).toDouble(),
        longitude: (e['lng'] as num).toDouble(),
      ))
          .toList(),
    );
  }
}
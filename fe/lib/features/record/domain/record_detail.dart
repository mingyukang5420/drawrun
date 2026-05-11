import 'package:running/shared/model/lat_lng.dart';

// 히스토리 상세 화면에 표시되는 한 기록의 전체 정보
//
// 매핑 대상: GET /api/v1/record/{recordId} 응답의 result.
// 상세 화면은 nodes(경로 좌표) 를 폴리라인으로 그려서 표시한다.
class RecordDetail {
  // 기록 식별자
  final int recordId;

  // 트랙(경로) 식별자 — 추후 경로 단독 조회용. 이번 화면에선 표시 안 함.
  final int trackId;

  // 코스 따라뛰기로 진행한 경우의 코스 ID. 자유 러닝이면 null.
  final int? courseId;

  // 에디터에서 만든 코스 드래프트로 진행한 경우의 ID. 자유 러닝이면 null.
  final int? courseDraftId;

  // 사용자가 지정한 러닝 제목
  final String title;

  // BE 가 포맷한 날짜 (예: "2026. 4. 27.")
  // 화면에는 "2025.04.27 오전 7:32" 같이 별도 표기가 필요할 수도 있지만,
  // BE 가 시작 시각(시·분) 까지는 안 내려주므로 일단 날짜만 그대로 노출한다.
  final String date;

  // 경로 미리보기 이미지 URL.
  //
  // 상세 화면 상단의 지도 영역에는 이 이미지를 정적 미리보기로 표시한다.
  // 자유롭게 패닝/줌이 가능한 인터랙티브 지도(네이버 맵 + 폴리라인) 는
  // "상세 경로 보기" 버튼으로 진입하는 별도 화면(RecordRouteScreen) 에서 그린다.
  //
  // 정책 이유:
  //   - 미리보기 단계에서 매번 NaverMap 을 띄우면 비용(타일 로딩, 메모리) 이 크다.
  //   - BE 가 이미 PNG 스냅샷을 만들어 trackImageUrl 로 내려주므로 그걸 그대로 쓰면 가볍다.
  //   - 사용자가 경로를 자세히 보고 싶을 때만 명시적으로 인터랙티브 화면을 연다.
  final String trackImageUrl;

  // 총 이동 거리 km
  final double distance;

  // 평균 페이스 "5'30''" 형식
  final String avgPace;

  // 러닝 시간 "MM:SS" 형식
  final String runningTime;

  // 소비 칼로리 (kcal). BE 가 정수로 줌.
  final int calories;

  // 분당 발걸음 수 (cadence)
  final int cadence;

  // 코스 따라뛰기 완주 여부. 자유 러닝일 때는 BE 가 true 로 채워서 줌.
  final bool isCompleted;

  // 도로 일치율 기반 안전성 플래그
  final bool isSafe;

  // 경로 좌표 목록. 지도에 폴리라인을 그릴 때 사용.
  // BE 응답 키는 lat/lng 이지만, 우리 공통 LatLng 모델은 latitude/longitude 를 쓰므로
  // fromJson 안에서 키를 매핑해준다.
  final List<LatLng> nodes;

  const RecordDetail({
    required this.recordId,
    required this.trackId,
    required this.courseId,
    required this.courseDraftId,
    required this.title,
    required this.date,
    required this.trackImageUrl,
    required this.distance,
    required this.avgPace,
    required this.runningTime,
    required this.calories,
    required this.cadence,
    required this.isCompleted,
    required this.isSafe,
    required this.nodes,
  });

  factory RecordDetail.fromJson(Map<String, dynamic> json) {
    // BE 응답의 nodes 배열은 [{ "lat": .., "lng": .. }, ...] 구조다.
    // 공통 LatLng 모델은 latitude/longitude 키를 쓰므로 여기서 직접 매핑한다.
    final rawNodes = json['nodes'] as List<dynamic>? ?? const [];
    final nodes = rawNodes
        .map((e) => e as Map<String, dynamic>)
        .map((e) => LatLng(
      latitude: (e['lat'] as num).toDouble(),
      longitude: (e['lng'] as num).toDouble(),
    ))
        .toList();

    return RecordDetail(
      recordId: json['recordId'] as int,
      trackId: json['trackId'] as int,
      // 자유 러닝이면 BE 가 null 을 내려주므로 nullable 그대로 받는다.
      courseId: json['courseId'] as int?,
      courseDraftId: json['courseDraftId'] as int?,
      title: json['title'] as String,
      date: json['date'] as String,
      trackImageUrl: json['trackImageUrl'] as String,
      distance: (json['distance'] as num).toDouble(),
      avgPace: json['avgPace'] as String,
      runningTime: json['runningTime'] as String,
      calories: json['calories'] as int,
      cadence: json['cadence'] as int,
      isCompleted: json['isCompleted'] as bool,
      isSafe: json['isSafe'] as bool,
      nodes: nodes,
    );
  }
}
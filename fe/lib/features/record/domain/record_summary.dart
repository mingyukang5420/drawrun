// 히스토리 목록의 카드 한 장에 해당하는 도메인 모델
//
// 매핑 대상: GET /api/v1/record 응답의 result.content[] 원소.
// BE 가 이미 사람이 읽을 수 있는 문자열(날짜/페이스/시간) 로 가공해서 보내주므로,
// FE 는 가공 없이 그대로 받아 화면에 표시한다.
class RecordSummary {
  // 기록 식별자 (상세 화면 진입 시 이 값으로 GET /api/v1/record/{recordId} 호출)
  final int recordId;

  // 사용자가 지정한 러닝 제목 (예: "역삼 댕댕이 런")
  final String title;

  // BE 가 포맷한 날짜 문자열 (예: "2026. 4. 27.")
  // FE 에서 DateTime 으로 다시 파싱하지 않는다 — 화면에 그대로 노출만.
  final String date;

  // 경로 미리보기 이미지 URL
  // 응답 예시: "https://k14a103.p.ssafy.io/uploads/tracks/xxxxx.jpg"
  // 화면에서는 작은 썸네일로만 사용 (Image.network)
  final String trackImageUrl;

  // 총 이동 거리 (km 단위 실수)
  final double distance;

  // BE 가 포맷한 평균 페이스 (예: "5'30''")
  // 표시 시 "5'30\"/km" 처럼 단위를 덧붙일지는 화면이 결정한다.
  final String avgPace;

  // BE 가 포맷한 러닝 시간 (예: "28:34")
  // 형식은 MM:SS — BE 가 시간 단위 변환 없이 분/초만 채워 보내준다.
  final String runningTime;

  const RecordSummary({
    required this.recordId,
    required this.title,
    required this.date,
    required this.trackImageUrl,
    required this.distance,
    required this.avgPace,
    required this.runningTime,
  });

  // 응답 result.content 의 원소 하나 → RecordSummary 변환
  // num.toDouble() 을 쓰는 이유: JSON 의 숫자는 Dart 에서 int 또는 double 일 수 있는데
  // 우리는 double 로만 다루고 싶으므로 안전 변환을 한 번 해준다.
  factory RecordSummary.fromJson(Map<String, dynamic> json) => RecordSummary(
    recordId: json['recordId'] as int,
    title: json['title'] as String,
    date: json['date'] as String,
    trackImageUrl: json['trackImageUrl'] as String,
    distance: (json['distance'] as num).toDouble(),
    avgPace: json['avgPace'] as String,
    runningTime: json['runningTime'] as String,
  );
}
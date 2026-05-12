// 통계 화면이 표시하는 기간 단위.
// BE 의 GET /api/v1/record/stats?period=... 쿼리값과 1:1 대응.
enum RecordStatsPeriod {
  // 이번 주 (월~일). 차트 라벨은 요일 한글자 (월/화/수/...).
  week('week', '주'),

  // 이번 달. 차트 라벨은 일자 (1, 2, ..., 31).
  month('month', '월'),

  // 올해. 차트 라벨은 월 (1월, 2월, ..., 12월).
  year('year', '년'),

  // 전체 누적. 차트 라벨은 연도 (예: 2024, 2025, 2026).
  all('all', '전체');

  // BE 쿼리 파라미터로 보낼 문자열
  final String apiValue;

  // 토글 UI 에 표시할 한글 라벨
  final String label;

  const RecordStatsPeriod(this.apiValue, this.label);
}

// 차트의 막대 한 개에 해당하는 데이터 포인트
class RecordStatsChartPoint {
  // 막대 아래에 표시되는 라벨 (예: "월", "5", "3월", "2026")
  final String label;

  // 막대 높이 계산용 거리 값 (km)
  final double distance;

  const RecordStatsChartPoint({
    required this.label,
    required this.distance,
  });

  factory RecordStatsChartPoint.fromJson(Map<String, dynamic> json) =>
      RecordStatsChartPoint(
        label: json['label'] as String,
        distance: (json['distance'] as num).toDouble(),
      );
}

// 통계 화면 한 페이지에 표시되는 전체 데이터
//
// 매핑 대상: GET /api/v1/record/stats?period=... 응답의 result.
class RecordStats {
  // 기간 내 총 이동 거리 (km)
  final double totalDistance;

  // 기간 내 러닝 횟수
  final int totalCount;

  // BE 가 포맷한 평균 페이스 (예: "5'28''")
  final String avgPace;

  // BE 가 포맷한 총 달린 시간 (예: "01:42:00")
  final String totalTime;

  // 기간을 사람이 읽을 수 있는 라벨로 변환한 문자열
  //  - week: "2026.04.27~2026.05.03"
  //  - month: "2026년 5월"
  //  - year: "2026년"
  //  - all: "2024년~2026년"
  final String periodLabel;

  // 차트에 표시할 막대들. 원소 개수와 라벨은 period 마다 다르다.
  final List<RecordStatsChartPoint> chart;

  const RecordStats({
    required this.totalDistance,
    required this.totalCount,
    required this.avgPace,
    required this.totalTime,
    required this.periodLabel,
    required this.chart,
  });

  factory RecordStats.fromJson(Map<String, dynamic> json) {
    final chartRaw = json['chart'] as List<dynamic>? ?? const [];
    final chart = chartRaw
        .map((e) => RecordStatsChartPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return RecordStats(
      totalDistance: (json['totalDistance'] as num).toDouble(),
      totalCount: json['totalCount'] as int,
      avgPace: json['avgPace'] as String,
      totalTime: json['totalTime'] as String,
      periodLabel: json['periodLabel'] as String,
      chart: chart,
    );
  }

  // 데이터가 한 건도 없을 때 화면에 보여줄 기본값.
  // ViewModel 의 초기 상태로 쓸 수 있어 별도 nullable 처리를 피한다.
  static const empty = RecordStats(
    totalDistance: 0,
    totalCount: 0,
    avgPace: "0'00''",
    totalTime: '00:00:00',
    periodLabel: '',
    chart: [],
  );
}
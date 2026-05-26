import 'package:running/features/record/domain/record_summary.dart';

// GET /api/v1/record 응답에서 한 페이지(슬라이스) 결과를 들고 다니는 컨테이너.
//
// 도메인 모델(RecordSummary) 자체는 화면에 표시되는 데이터지만,
// 페이지네이션 정보(page/size/hasNext) 는 "이번 페이지를 끝으로 더 불러올지" 결정하는
// 데이터 흐름 메타라서 data 계층에 둔다.
class RecordSummaryPage {
  // 이번 페이지에 들어 있는 기록 카드들
  final List<RecordSummary> items;

  // 0부터 시작하는 페이지 번호 (요청 시 사용한 값과 같음)
  final int page;

  // 한 페이지 크기 (요청 시 사용한 값과 같음)
  final int size;

  // true 면 더 다음 페이지가 있음 → 무한스크롤 시 추가 호출
  // false 면 마지막 페이지 → 더 이상 GET 호출 X
  final bool hasNext;

  const RecordSummaryPage({
    required this.items,
    required this.page,
    required this.size,
    required this.hasNext,
  });

  // 응답 result(=Slice 구조) → RecordSummaryPage 변환
  factory RecordSummaryPage.fromJson(Map<String, dynamic> json) {
    final raw = json['content'] as List<dynamic>? ?? const [];
    return RecordSummaryPage(
      items: raw
          .map((e) => RecordSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      size: json['size'] as int,
      hasNext: json['hasNext'] as bool,
    );
  }
}
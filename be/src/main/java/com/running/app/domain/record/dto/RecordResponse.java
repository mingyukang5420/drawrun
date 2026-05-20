package com.running.app.domain.record.dto;

import com.running.app.domain.track.dto.TrackRequest;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class RecordResponse {

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ListDTO {

        private Long recordId;
        private String title;
        private String date;
        private String trackImageUrl;
        private Double distance;
        private String avgPace;
        private String runningTime;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ListResultDTO {

        private List<ListDTO> content;
        private Integer page; //현재 페이지
        private Integer size; //기본값 10으로 둘 예정
        private Boolean hasNext; //Slice 조회용
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DetailDTO {

        private Long recordId;
        private Long trackId;
        private Long courseId;
        private Long courseDraftId;
        private String title;
        private String date;
        private String startedAt;
        private String trackImageUrl;
        private Double distance;
        private String avgPace;
        private String runningTime;
        private Integer calories;
        private Integer cadence;
        private Boolean isCompleted;
        private Boolean isSafe;
        private List<TrackRequest.NodeDTO> nodes;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class StatsDTO {

        private Double totalDistance;
        private Integer totalCount;
        private String avgPace;
        private String totalTime;
        private String periodLabel;
        private List<ChartDTO> chart;

        // 마이페이지 잔디 위젯용 — 이번 주(월요일 시작) 포함 최근 12주(약 3개월) 의 주별 활동.
        // period 값과 무관하게 항상 같은 12주 데이터가 들어간다 (잔디는 별도 트랙).
        // 활동이 없던 주도 distance=0.0, count=0 으로 빠짐없이 채워 정확히 12개를 보장.
        private List<WeeklyActivityDTO> weeklyActivity;

    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChartDTO {

        //차트는 우선 달린 거리 데이터만(nikerun)
        private String label;
        private Double distance;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class WeeklyActivityDTO {

        // 주의 시작일 (월요일, yyyy-MM-dd) — FE 가 잔디 셀 매핑 / tooltip 라벨에 사용
        private String weekStart;
        // 그 주의 누적 거리(km). 활동 없으면 0.0
        private Double distance;
        // 그 주의 러닝 횟수. 활동 없으면 0 — FE 가 "한 번이라도 뛰었는지" 판단에 사용
        private Integer count;
    }
}

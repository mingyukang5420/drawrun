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
}

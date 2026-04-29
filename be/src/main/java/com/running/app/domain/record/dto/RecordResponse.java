package com.running.app.domain.record.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

public class RecordResponse {

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateResultDTO {

        private Long recordId;
        private Long trackId;
        private Long courseId;
        private String title;
        private Double distance;
        private String trackImageUrl;
        private Integer runningTime;
        private Double avgPace;
        private Integer calories;
        private Integer cadence;
        private Boolean isCompleted;
        private Boolean isSafe;
    }

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
}

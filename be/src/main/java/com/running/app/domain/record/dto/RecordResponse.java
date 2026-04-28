package com.running.app.domain.record.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

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
}

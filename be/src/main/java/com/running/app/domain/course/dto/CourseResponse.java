package com.running.app.domain.course.dto;

import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class CourseResponse {

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CourseListDTO {

        private Long courseId;
        private String title;
        private String difficulty;
        private Double distance;
        private List<String> regions;
        private Boolean isCompleted;
        private String thumbnailUrl;
        private String createdAt;
        private Integer completionScore;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CourseListResultDTO {

        private List<CourseListDTO> content;
        private Integer page;
        private Integer size;
        private Boolean hasNext;
    }
}
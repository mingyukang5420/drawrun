package com.running.app.domain.course.dto;

import java.util.List;

import com.running.app.domain.track.dto.TrackRequest;
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

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CourseDetailDTO {

        private Long courseId;
        private String title;
        private String difficulty;
        private List<String> regions;
        private Integer completionScore;
        private String thumbnailUrl;
        private Double distance;
        private Boolean isCompleted;
        private String createdAt;
        private List<TrackRequest.NodeDTO> nodes;
    }
}
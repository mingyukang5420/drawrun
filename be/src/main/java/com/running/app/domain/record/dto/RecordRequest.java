package com.running.app.domain.record.dto;

import com.running.app.domain.track.dto.TrackRequest;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

public abstract class RecordRequest {

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateDTO {

        private Long courseId;
        private String title;
        private Double distance;
        private String trackImageUrl;
        private Integer runningTime;
        private Double avgPace;
        private Integer calories;
        private Integer cadence;
        private LocalDateTime startedAt;
        private LocalDateTime endedAt;
        private List<TrackRequest.NodeDTO> nodes;
    }
}
